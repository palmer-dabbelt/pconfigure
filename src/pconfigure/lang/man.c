
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

#include "man.h"
#include <string.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

/* Instance methods. */
static struct language *language_man_search(struct language *l_uncast,
                                            struct language *parent,
                                            const char *path,
                                            struct context *c);

struct language *language_man_new(struct clopts *o, const char *name)
{
    struct language_pkgconfig *l;

    if (strcmp(name, "man") != 0)
        return NULL;

    l = talloc_get_type(language_pkgconfig_new(o, "pkgconfig"),
                        struct language_pkgconfig);
    if (l == NULL)
        return NULL;

    l->l.name = talloc_strdup(l, "man");
    l->l.compiled = false;
    l->l.compile_str = talloc_strdup(l, "MAN");
    l->l.link_str = talloc_strdup(l, "MAN");
    l->l.search = &language_man_search;

    return &(l->l);
}

struct language *language_man_search(struct language *l_uncast,
                                     struct language *parent,
                                     const char *path,
                                     struct context *c)
{
    struct language_pkgconfig *l;

    l = talloc_get_type(l_uncast, struct language_pkgconfig);
    if (l == NULL)
        return NULL;

    if (strcmp(path + strlen(path) - 4, ".man") != 0)
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->name, l_uncast->name) != 0)
        return NULL;

    return l_uncast;
}
