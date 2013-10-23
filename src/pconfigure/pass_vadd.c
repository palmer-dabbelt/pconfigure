
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

#include "pass_vadd.h"
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static bool busy = false;
static struct makefile *_mf;

static void vadd_dep(void *unused, const char *format, ...);

extern void language_deps_vadd_dep(struct language *l, struct context *c,
                                   struct makefile *mf)
{
    if (busy == true) {
        fprintf(stderr, "Detected recursive language_deps_vadd_dep() call\n");
        abort();
    }

    busy = true;

    _mf = mf;
    language_deps(l, c, &vadd_dep, NULL);

    busy = false;
}

void vadd_dep(void *unused, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    makefile_vadd_dep(_mf, format, args);
    va_end(args);
}
