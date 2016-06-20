
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

/* Pretty much does sed, but with a bit of massaging and only
 * string-to-string. */
static char *replace(const char *line, const char *pair);

int main(int argc, char **argv)
{
    char *input, *output;
    char *last;
    char **dirs;
    char **defs;
    int dirs_count;
    int defs_count;
    int i;
    char *chmod;
    int chmod_size;
    int ret;

    input = NULL;
    output = NULL;
    last = NULL;
    dirs_count = 0;
    defs_count = 0;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0)
            last = argv[i];
        else if (strncmp(argv[i], "-I", 2) == 0)
            dirs_count++;
        else if (strncmp(argv[i], "-D", 2) == 0)
            defs_count++;
        else if (last == NULL)
            input = argv[i];
        else if (strcmp(last, "-o") == 0) {
            output = argv[i];
            last = NULL;
        }
    }

    dirs = malloc(sizeof(*dirs) * (dirs_count + 1));
    dirs_count = 0;
    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-I", 2) == 0) {
            dirs[dirs_count] = argv[i] + 2;
            dirs_count++;
        }
    }
    dirs[dirs_count] = NULL;

    defs = malloc(sizeof(*defs) * (defs_count + 1));
    defs_count = 0;
    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-D", 2) == 0) {
            defs[defs_count] = argv[i] + 2;
            defs_count++;
        }
    }
    defs[defs_count] = NULL;

    if ((input == NULL) || (output == NULL)) {
        fprintf(stderr, "needs 2 arguments\ninput '%s'\noutput '%s'\n",
                input, output);
        exit(1);
    }

    outfile = fopen(output, "w");

    fprintf(outfile, SHEBANG "\n");

    if (pinclude_lines(input, NULL, NULL, &write_line, defs, (const char **)dirs, (const char **)defs, 1) != 0) {
        fprintf(stderr, "pinclude failed to parse input: '%s'\n", input);
        abort();
    }

    fclose(outfile);

    chmod_size = strlen("chmod oug+x ") + strlen(output) + 1;
    chmod = malloc(chmod_size);
    snprintf(chmod, chmod_size, "chmod oug+x %s", output);
    ret = system(chmod);
    free(chmod);
    return ret;
}

int write_line(const char *line, void *defs_uncast)
{
    const char **defs = defs_uncast;
    char *new_line = strdup(line);
    while (*defs != NULL) {
        char *old_line = new_line;
        if (strstr(*defs, "=") != NULL) {
            new_line = replace(old_line, *defs);
            free(old_line);
        }
        defs++;
    }

    fputs(new_line, outfile);
    free(new_line);

    return 0;
}

char *replace(const char *line, const char *pair)
{
    char *from, *to, *out;
    int count;
    size_t ii, oi;

    to = strstr(pair, "=");
    if (to == NULL)
        return strdup(line);

    from = strndup(pair, to - pair);
    to++;

    count = 0;
    for (ii = 0; ii < strlen(line); ++ii)
        if (strncmp(line + ii, from, strlen(from)) == 0)
            count++;

    out = malloc(strlen(line)
                 + (strlen(to) * count)
                 - (strlen(from) * count)
                 + 1);
    if (out == NULL) {
        perror("Unable to malloc()");
        free(from);
        return NULL;
    }

    ii = oi = 0;
    out[0] = '\0';
    while (ii < strlen(line)) {
        if (strncmp(line + ii, from, strlen(from)) == 0) {
            strcat(out + oi, to);
            ii += strlen(from);
            oi += strlen(to);
        } else {
            out[oi] = line[ii];
            oi++;
            ii++;
            out[oi] = '\0';
        }
    }

    free(from);
    return out;
}
