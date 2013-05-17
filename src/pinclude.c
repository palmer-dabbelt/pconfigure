
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

static int callback(const char *filename, void *unused);

int main(int argc __attribute__ ((unused)),
         char **argv __attribute__ ((unused)))
{
    char *dirs[1];

    if (argc != 2)
        return 1;

    dirs[0] = NULL;
    return pinclude_list(argv[1], &callback, NULL, dirs);
}

int callback(const char *filename, void *unused)
{
    printf("%s\n", filename);
    return 0;
}
