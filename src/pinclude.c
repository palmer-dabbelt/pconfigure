
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

#include <pinclude.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int callback(const char *filename, void *unused);

int main(int argc __attribute__ ((unused)),
         char **argv __attribute__ ((unused)))
{
    int dir_count;
    char **dirs;
    char *defs[1];
    char *input;
    int i;

    input = NULL;
    dir_count = 0;
    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-I", 2) == 0)
            dir_count++;
        else
            input = argv[i];
    }

    dirs = malloc(sizeof(*dirs) * (dir_count + 1));
    dir_count = 0;
    for (i = 1; i < argc; i++) {
        if (strncmp(argv[i], "-I", 2) == 0) {
            dirs[dir_count] = argv[i] + 2;
            dir_count++;
        }
    }
    dirs[dir_count] = NULL;

    if (input == NULL)
        return 0;

    defs[0] = NULL;
    return pinclude_list(input, &callback, NULL, dirs, defs);
}

int callback(const char *filename, void *unused)
{
    printf("%s\n", filename);
    return 0;
}
