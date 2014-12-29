
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
#include <pinclude.h>

#ifndef SHEBANG_PREFIX
#define SHEBANG_PREFIX ""
#endif

#if defined(LANG_PERL)

#if defined(__gnu_linux__) || defined(__APPLE__)
#define SHEBANG "#!" SHEBANG_PREFIX "/usr/bin/perl\n"
#else
#error "Where does Perl live on this system?"
#endif

#elif defined(LANG_BASH)

#if defined(__gnu_linux__) || defined(__APPLE__)
#define SHEBANG "#!" SHEBANG_PREFIX "/bin/bash\n"
#else
#error "Where does Bash live on this system?"
#endif

#else
#error "No language defined"
#endif

/* The output file is a global file. */
static FILE *outfile;

/* Writes a line out to the output file. */
static int write_line(const char *line, void *unused);

int main(int argc, char **argv)
{
    char *input, *output;
    char *last;
    char **dirs;
    int dirs_count;
    char *defs[1];
    int i;
    char *chmod;
    int chmod_size;
    int ret;

    input = NULL;
    output = NULL;
    last = NULL;
    dirs_count = 0;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0)
            last = argv[i];
        else if (last == NULL)
            input = argv[i];
        else if (strcmp(last, "-o") == 0) {
            output = argv[i];
            last = NULL;
        } else if (strncmp(argv[i], "-I", 2) == 0) {
            dirs_count++;
        }
    }

    dirs = malloc(sizeof(*dirs) * (dirs_count + 1));
    dirs_count = 0;
    defs[0] = NULL;
    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-I", 2) == 0) {
            dirs[dirs_count] = argv[i] + 2;
            dirs_count++;
        }
    }
    dirs[dirs_count] = NULL;

    if ((input == NULL) || (output == NULL)) {
        fprintf(stderr, "needs 2 arguments\ninput '%s'\noutput '%s'\n",
                input, output);
        exit(1);
    }

    outfile = fopen(output, "w");

    fprintf(outfile, SHEBANG "\n");

    pinclude_lines(input, NULL, NULL, &write_line, NULL, dirs, defs);

    fclose(outfile);

    chmod_size = strlen("chmod oug+x ") + strlen(output) + 1;
    chmod = malloc(chmod_size);
    snprintf(chmod, chmod_size, "chmod oug+x %s", output);
    ret = system(chmod);
    free(chmod);
    return ret;
}

int write_line(const char *line, void *unused __attribute__ ((unused)))
{
    fputs(line, outfile);
    return 0;
}
