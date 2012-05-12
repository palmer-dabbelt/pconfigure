
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

#include "language.h"

int language_init(struct language *l)
{
    if (l == NULL)
        return -1;

    l->name = NULL;
    l->link_name = NULL;
    l->compiled = false;
    l->compile_opts = stringlist_new(l);
    l->link_opts = stringlist_new(l);
    l->search = NULL;
    l->objname = NULL;
    l->deps = NULL;
    l->build = NULL;
    l->link = NULL;
    l->extras = NULL;

    return 0;
}

int language_add_compileopt(struct language *l, const char *opt)
{
    if (l == NULL)
        return -1;
    if (opt == NULL)
        return -1;
    if (l->compile_opts == NULL)
        return -1;

    return stringlist_add(l->compile_opts, opt);
}

int language_add_linkopt(struct language *l, const char *opt)
{
    if (l == NULL)
        return -1;
    if (opt == NULL)
        return -1;
    if (l->link_opts == NULL)
        return -1;

    return stringlist_add(l->link_opts, opt);
}

struct language *language_search(struct language *l,
                                 struct language *parent, const char *path)
{
    assert(l != NULL);
    assert(l->search != NULL);
    return l->search(l, parent, path);
}

const char *language_objname(struct language *l, void *context,
                             struct context *c)
{
    assert(l != NULL);
    assert(l->objname != NULL);
    return l->objname(l, context, c);
}

bool language_needs_compile(struct language * l, struct context * c)
{
    assert(l != NULL);
    return l->compiled;
}

void language_deps(struct language *l, struct context *c,
                   void (*func) (const char *, ...))
{
    assert(l != NULL);
    assert(l->deps != NULL);
    l->deps(l, c, func);
}

void language_build(struct language *l, struct context *c,
                    void (*func) (bool, const char *, ...))
{
    assert(l != NULL);
    assert(l->build != NULL);
    l->build(l, c, func);
}

void language_link(struct language *l, struct context *c,
                   void (*func) (bool, const char *, ...))
{
    assert(l != NULL);
    assert(l->link != NULL);
    l->link(l, c, func);
}

void language_extras(struct language *l, struct context *c, void *context,
                     void (*func) (const char *))
{
    assert(l != NULL);
    assert(l->extras != NULL);
    l->extras(l, c, context, func);
}
