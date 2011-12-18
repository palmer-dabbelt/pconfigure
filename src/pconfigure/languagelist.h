
/*
 * Copyright (C) 2011 Daniel Dabbelt
 *   <palmem@comcast.net>
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

#ifndef PCONFIGURE_LANGUAGELIST_H
#define PCONFIGURE_LANGUAGELIST_H

#include "language.h"
#include "clopts.h"

struct languagelist_node
{
    struct language *data;
    struct languagelist_node *next;
};

struct languagelist
{
    struct languagelist_node *head;
    struct language *selected;
};

extern struct languagelist *languagelist_new(struct clopts *o);

extern int languagelist_select(struct languagelist *ll, const char *name);

extern struct language *languagelist_get(struct languagelist *ll,
                                         void *context);

#endif
