
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

#include <pinclude.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LINE_MAX 1024
#define FILE_MAX 1024

static int _pinclude_list(const char *input, pinclude_callback_t cb,
                          void *priv, char **include_dirs, char **included)
{
    int err;
    FILE *infile;
    char buffer[LINE_MAX];
    size_t i;

    infile = fopen(input, "r");

    if (infile == NULL)
        return -1;

    while (fgets(buffer, LINE_MAX, infile) != NULL) {
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

                if ((err = cb(full_path, priv)) != 0) {
                    free(dir_path);
                    free(filename);
                    free(full_path);

                    return err;
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

                    if ((err = cb(full_path, priv)) != 0) {
                        free(dir_path);
                        free(filename);
                        free(full_path);

                        return err;
                    }

                    goto skip_dirs;
                }
            }

          skip_dirs:
            err = _pinclude_list(full_path, cb, priv, include_dirs, included);

          skip_file:
            free(dir_path);
            free(filename);
            free(full_path);

            /* We want to skip this whole line */
            continue;
        }
    }

    fclose(infile);

    return 0;
}

int pinclude_list(const char *input, pinclude_callback_t cb,
                  void *priv, char **include_dirs)
{
    int err;
    int i;
    char *included[LINE_MAX];

    for (i = 0; i < LINE_MAX; i++)
        included[i] = NULL;

    err = _pinclude_list(input, cb, priv, include_dirs, included);

    for (i = 0; i < FILE_MAX; i++)
        if (included[i] != NULL)
            free(included[i]);

    return err;
}
