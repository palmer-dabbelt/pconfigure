
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

#define _GNU_SOURCE

#include <pinclude.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LINE_MAX 1024

int pinclude_list(const char *input, pinclude_callback_t cb, void *priv)
{
    int err;
    FILE *infile;
    char buffer[LINE_MAX];

    infile = fopen(input, "r");

    if (infile == NULL)
        return -1;

    while (fgets(buffer, LINE_MAX, infile) != NULL)
    {
        if (strncmp(buffer, "#include \"", strlen("#include \"")) == 0)
        {
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

            asprintf(&full_path, "%s/%s", dir_path, filename);

            if (access(full_path, R_OK) == 0)
            {
                if ((err = cb(full_path, priv)) != 0)
                {
                    free(dir_path);
                    free(filename);
                    free(full_path);

                    return err;
                }
            }

            err = pinclude_list(full_path, cb, priv);

            free(dir_path);
            free(filename);
            free(full_path);

            if (err != 0)
            {
                fclose(infile);
                return err;
            }

            /* We want to skip this whole line */
            continue;
        }
    }

    fclose(infile);

    return 0;
}
