
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

#include "pass_cspush.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static bool busy = false;
static struct language *_l;
static struct contextstack *_s;
static void *_context;

static void pass_cs_push_fs(void *unused, const char *extra);

extern void language_extras_pass_cs_push_fs(struct language *l,
                                            struct context *c,
                                            void *context,
                                            struct contextstack *s)
{
    if (busy == true) {
        fprintf(stderr, "Recursive language_extras_pass_cs_push_fs()\n");
        abort();
    }

    busy = true;

    _l = l;
    _s = s;
    _context = context;
    language_extras(l, c, context, &pass_cs_push_fs, NULL);

    busy = false;
}

void pass_cs_push_fs(void *unused, const char *extra)
{
    contextstack_push_fullsrc(_s, extra);
}
