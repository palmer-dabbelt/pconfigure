
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

#include "pass_vcmd.h"

#include <stdbool.h>
#include <stdlib.h>

static bool busy = false;
static struct context *_c;

static void pass_vcmd_func(bool nam, const char *format, ...);

void language_link_pass_vcmd(struct language *l, struct context *c,
                             bool to_install)
{
    if (busy == true) {
        fprintf(stderr,
                "Detected recursive language_link_pass_vcmd() call\n");
        abort();
    }

    busy = true;
    _c = c;

    language_link(l, c, &pass_vcmd_func, to_install);

    _c = NULL;
    busy = false;
}

void language_slib_pass_vcmd(struct language *l, struct context *c)
{
    if (busy == true) {
        fprintf(stderr,
                "Detected recursive language_slib_pass_vcmd() call\n");
        abort();
    }

    busy = true;
    _c = c;

    language_slib(l, c, &pass_vcmd_func);

    _c = NULL;
    busy = false;
}

void language_build_pass_vcmd(struct language *l, struct context *c)
{
    if (busy == true) {
        fprintf(stderr,
                "Detected recursive language_build_pass_vcmd() call\n");
        abort();
    }

    busy = true;
    _c = c;

    language_build(l, c, &pass_vcmd_func);

    _c = NULL;
    busy = false;
}

void pass_vcmd_func(bool nam, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    if (nam == true)
        makefile_vnam_cmd(_c->mf, format, args);
    else
        makefile_vadd_cmd(_c->mf, format, args);
    va_end(args);
}
