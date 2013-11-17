
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

#ifndef PCONFIGURE_LANG_C_H
#define PCONFIGURE_LANG_C_H

#include "../language.h"
#include "../clopts.h"

struct language_c
{
    struct language l;

    /* These allow subclasses of language_c to override what variable
     * name their flags take.  Note that this must be specified as the
     * whole make line (ie, "$(CFLAGS)"), which allows for trickier
     * sorts of overriding. */
    const char *cflags;
    const char *ldflags;
};

extern struct language_c *language_c_new_uc(struct clopts *o,
                                            const char *name);

static __inline__ struct language *language_c_new(struct clopts *o,
                                                  const char *name)
{
    return &(language_c_new_uc(o, name)->l);
}

#endif
