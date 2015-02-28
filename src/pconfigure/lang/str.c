
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

#include "str.h"
#include <string.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

bool str_sta(const char *haystack, const char *needle)
{
    if (haystack == NULL)
        return false;
    if (needle == NULL)
        return false;

    return (strncmp(haystack, needle, strlen(needle)) == 0);
}

const char *remove_dotdot(void *c, const char *str)
{
    char *out;
    size_t i;

    out = talloc_strdup(c, str);
    for (i = 0; i < strlen(str); ++i) {
        if (strncmp(str + i, "..", 2) == 0) {
            out[i + 0] = '_';
            out[i + 1] = '_';
        }
    }

    return out;
}
