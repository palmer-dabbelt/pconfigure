
/*
 * Copyright (C) 2013 Palmer Dabbelt
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

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <ctype.h>
#include <pinclude.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LINE_MAX 1024
#define FILE_MAX 1024
#define NEST_MAX 32

#ifndef DEBUG_LIBPINLCUDE_EACHLINE

#ifdef DEBUG_LIBPINCLUDE_DEFINE
#define DEBUG_LIBPINCLUDE_EACHLINE
#endif

#ifdef DEBUG_LIBPINCLUDE_INCLUDE
#define DEBUG_LIBPINCLUDE_EACHLINE
#endif

#endif /* DEBUG_LIBPINCLUDE_EACHLINE */

static void str_chomp(char *str);

static int _pinclude_lines(const char *input,
                           pinclude_callback_t per_include,
                           void *include_priv, pinclude_lineback_t per_line,
                           void *line_priv, char **include_dirs,
                           char **defined, char **included)
{
    int err;
    FILE *infile;
    char buffer[LINE_MAX];
    size_t i;
    bool state[NEST_MAX];
    int state_i;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
    fprintf(stderr, "input: '%s'\n", input);
#endif

    if (input[0] == '/')
        return 0;

    infile = fopen(input, "r");

    if (infile == NULL)
        return -1;

    state_i = 0;
    state[state_i] = true;

    while (fgets(buffer, LINE_MAX, infile) != NULL) {
#ifdef DEBUG_LIBPINCLUDE_EACHLINE
        fprintf(stderr, "    %s", buffer);
#endif

        /* Here's where we handle the #if{,n}def preprocessor
         * directives. */
        if (strncmp(buffer, "#ifdef ", strlen("#ifdef ")) == 0) {
            char *define;
            bool matched;

            define = buffer + strlen("#ifdef ");
            str_chomp(define);

            matched = false;
            for (i = 0; defined[i] != NULL; i++)
                if (strcmp(define, defined[i]) == 0)
                    matched = true;

            state_i++;
            state[state_i] = matched;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "ifdef: '%s' (%d -> %d)\n",
                    define, state_i, state[state_i]);
#endif
        }

        if (strncmp(buffer, "#ifndef ", strlen("#ifndef ")) == 0) {
            char *define;
            bool matched;

            define = buffer + strlen("#ifndef ");
            str_chomp(define);

            matched = false;
            for (i = 0; defined[i] != NULL; i++)
                if (strcmp(define, defined[i]) == 0)
                    matched = true;

            state_i++;
            state[state_i] = !matched;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "ifndef: '%s' (%d -> %d)\n",
                    define, state_i, state[state_i]);
#endif
        }

        if (strncmp(buffer, "#else", strlen("#else")) == 0) {
            state[state_i] = !state[state_i];

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "else: (%d -> %d)\n", state_i, state[state_i]);
#endif
        }

        /* FIXME: I'm just faking support for #if here because I don't
         * want to solve equations.  This keeps the stack correct but
         * doesn't actually handle the check. */
        if (strncmp(buffer, "#if ", strlen("#if ")) == 0) {
            state_i++;
            state[state_i] = true;
        }

        if (strncmp(buffer, "#endif", strlen("#endif")) == 0) {
            if (state_i == 0)
                abort();

            state_i--;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "endif: (%d -> %d)\n", state_i, state[state_i]);
#endif
        }

        /* If we're #ifdef'd out then skip the line. */
        if (state[state_i] == false)
            continue;

        /* Here's a hack: treat <> includes just like "" includes. */
        if (strncmp(buffer, "#include <", strlen("#include <")) == 0) {
            buffer[strlen("#include <") - 1] = '"';
            strstr(buffer, ">")[0] = '"';

#ifdef DEBUG_LIBPINCLUDE_INCLUDE
            fprintf(stderr, "include -> %s", buffer);
#endif
        }

        /* Finally attempt to recursively enumerate the #include
         * files. */
        if (strncmp(buffer, "#include \"", strlen("#include \"")) == 0) {
            size_t slash_max;

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

            if (strlen(dir_path) == 0)
                strcpy(dir_path, ".");

            /* Pull FILENAME out of #include "FILENAME" */
            filename = strdup(buffer + strlen("#include \""));
            filename[strlen(filename) - 2] = '\0';

            if (strcmp(dir_path, ".") != 0) {
                if (asprintf(&full_path, "%s/%s", dir_path, filename) < 0)
                    abort();
            } else {
                if (asprintf(&full_path, "%s", filename) < 0)
                    abort();
            }

            for (i = 0; i < FILE_MAX; i++)
                if (included[i] != NULL
                    && strcmp(full_path, included[i]) == 0)
                    goto skip_file;

            if (access(full_path, R_OK) == 0) {
                for (i = 0; i < FILE_MAX; i++) {
                    if (included[i] != NULL)
                        continue;

                    included[i] = strdup(full_path);
                    break;
                }

#ifdef DEBUG_LIBPINCLUDE_INCLUDE
                fprintf(stderr, "inc: '%s'\n", full_path);
#endif

                if (per_include != NULL) {
                    if ((err = per_include(full_path, include_priv)) != 0) {
                        free(dir_path);
                        free(filename);
                        free(full_path);

                        return err;
                    }
                }

                goto skip_dirs;
            }

            /* Check each additional include directory */
            for (i = 0; include_dirs[i] != NULL; i++) {
                size_t fi;

                free(full_path);
                if (asprintf(&full_path, "%s/%s", include_dirs[i], filename) <
                    0)
                    abort();

                for (fi = 0; fi < FILE_MAX; fi++)
                    if (included[fi] != NULL
                        && strcmp(full_path, included[fi]) == 0)
                        goto skip_file;

                if (access(full_path, R_OK) == 0) {
                    for (i = 0; i < FILE_MAX; i++) {
                        if (included[i] != NULL)
                            continue;

                        included[i] = strdup(full_path);
                        break;
                    }

                    if (per_include != NULL) {
                        if ((err = per_include(full_path, include_priv)) != 0) {
                            free(dir_path);
                            free(filename);
                            free(full_path);

                            return err;
                        }
                    }

                    goto skip_dirs;
                }
            }

          skip_dirs:
            _pinclude_lines(full_path,
                            per_include, include_priv,
                            per_line, line_priv,
                            include_dirs, defined, included);

          skip_file:
            free(dir_path);
            free(filename);
            free(full_path);

            /* We want to skip this whole line */
            continue;
        }
    }

    fclose(infile);

#ifdef DEBUG_LIBPINCLUDE_DEFINE
    fprintf(stderr, "close: '%s'\n", input);
#endif
    return 0;
}

int pinclude_list(const char *filename, pinclude_callback_t cb, void *priv,
                  char **include_dirs, char **defined)
{
    return pinclude_lines(filename,
                          cb, priv, NULL, NULL, include_dirs, defined);
}

int pinclude_lines(const char *filename,
                   pinclude_callback_t per_include, void *include_priv,
                   pinclude_lineback_t per_line, void *line_priv,
                   char **include_dirs, char **defined)
{
    int err;
    int i;
    char *included[LINE_MAX];

    for (i = 0; i < LINE_MAX; i++)
        included[i] = NULL;

    err = _pinclude_lines(filename,
                          per_include, include_priv,
                          per_line, line_priv,
                          include_dirs, defined, included);

    for (i = 0; i < FILE_MAX; i++)
        if (included[i] != NULL)
            free(included[i]);

    return err;
}

void str_chomp(char *str)
{
    while ((strlen(str) > 0) && isspace(str[strlen(str) - 1]))
        str[strlen(str) - 1] = '\0';
}
