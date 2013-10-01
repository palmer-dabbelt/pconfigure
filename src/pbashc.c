
/*
 * Copyright (C) 2011 Palmer Dabbelt
 *   <palmer@dabbelt.com>
 *
 * This file is part of pconfigure.
 * 
 * pconfigure is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * pconfigure is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with pconfigure.  If not, see <http://www.gnu.org/licenses/>.
 */

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef SHEBANG
#if defined(LANG_PERL)
#define SHEBANG "#!/usr/bin/perl\n"
#elif defined(LANG_BASH)
#define SHEBANG "#!/bin/bash\n"
#else
#error "No language defined"
#endif
#endif

/* The output file is a global file. */
static FILE *outfile;

/* This cats a single input file to the output file. */
static void cat_to_outfile(const char *input);

int main(int argc, char **argv)
{
    char *input, *output;
    char *last;
    int i;
    char *chmod;
    int chmod_size;

    input = NULL;
    output = NULL;
    last = NULL;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0)
            last = argv[i];
        else if (last == NULL)
            input = argv[i];
        else if (strcmp(last, "-o") == 0) {
            output = argv[i];
            last = NULL;
        }
    }

    if ((input == NULL) || (output == NULL)) {
        fprintf(stderr, "needs 2 arguments\ninput '%s'\noutput '%s'\n",
                input, output);
        exit(1);
    }

    outfile = fopen(output, "w");

    fprintf(outfile, SHEBANG "\n");

    cat_to_outfile(input);
    fclose(outfile);

    chmod_size = strlen("chmod oug+x ") + strlen(output) + 1;
    chmod = malloc(chmod_size);
    snprintf(chmod, chmod_size, "chmod oug+x %s", output);
    return system(chmod);
}

void cat_to_outfile(const char *input)
{
    FILE *infile;
    char buffer[1024];

    infile = fopen(input, "r");

    while (fgets(buffer, 1024, infile) != NULL) {
        if (strncmp(buffer, "#include \"", strlen("#include \"")) == 0) {
            size_t i, slash_max;

            char *full_path;
            char *dir_path;
            char *filename;

            /* dir_path = dirname(input) */
            dir_path = strdup(input);
            slash_max = 0;
            for (i = 0; i < strlen(dir_path); i++)
                if (dir_path[i] == '/')
                    slash_max = i;
            dir_path[slash_max] = '\0';

            /* Pull FILENAME out of #include "FILENAME" */
            filename = strdup(buffer + strlen("#include \""));
            filename[strlen(filename) - 2] = '\0';

            if (strlen(dir_path) == 0) {
                if (asprintf(&full_path, "%s", filename) < 0)
                    abort();
            } else {
                if (asprintf(&full_path, "%s/%s", dir_path, filename) < 0)
                    abort();
            }

            cat_to_outfile(full_path);

            free(dir_path);
            free(filename);
            free(full_path);

            /* We want to skip this whole line */
            continue;
        }

        if (fputs(buffer, outfile) <= 0)
            exit(1);
    }

    fclose(infile);

    return;
}
