
/*
 * Copyright (C) 2011,2013 Palmer Dabbelt
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
#include "funcs.h"

#include <ctype.h>
#include <string.h>
#include <unistd.h>
#include <pinclude.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

static struct language *language_man_search(struct language *l_uncast,
                                            struct language *parent,
                                            const char *path,
                                            struct context *c);
static const char *language_man_objname(struct language *l_uncast,
                                        void *context, struct context *c);
static void language_man_deps(struct language *l_uncast, struct context *c,
                              void (*func) (void *, const char *, ...),
                              void *arg);
static void language_man_build(struct language *l_uncast, struct context *c,
                               void (*func) (bool, const char *, ...));
static void language_man_link(struct language *l_uncast, struct context *c,
                              void (*func) (bool, const char *, ...),
                              bool should_install);
static void language_man_extras(struct language *l_uncast, struct context *c,
                                void *context,
                                void (*func) (void *, const char *), void *arg);

struct language *language_man_new(struct clopts *o, const char *name)
{
    struct language_man *l;

    if (strcmp(name, "man") != 0)
        return NULL;

    l = talloc(o, struct language_man);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "man");
    l->l.compiled = false;
    l->l.compile_str = talloc_strdup(l, "");
    l->l.compile_cmd = talloc_strdup(l, "");
    l->l.link_str = talloc_strdup(l, "MAN");
    l->l.link_cmd = talloc_strdup(l, "cp");
    l->l.search = &language_man_search;
    l->l.objname = &language_man_objname;
    l->l.deps = &language_man_deps;
    l->l.build = &language_man_build;
    l->l.link = &language_man_link;
    l->l.extras = &language_man_extras;

    return &(l->l);
}

struct language *language_man_search(struct language *l_uncast,
                                     struct language *parent,
                                     const char *path, struct context *c)
{
    struct language_man *l;

    l = talloc_get_type(l_uncast, struct language_man);
    if (l == NULL)
        return NULL;

    if ((strcmp(path + strlen(path) - 2, ".") != 0)
        && !isdigit(path[strlen(path)-1]))
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->link_name, l_uncast->link_name) != 0)
        return NULL;

    c->parent->link_path = talloc_strdup(c->parent, c->full_path);

    return l_uncast;
}

const char *language_man_objname(struct language *l_uncast, void *context,
                                 struct context *c)
{
    abort();
    return NULL;
}

void language_man_deps(struct language *l_uncast, struct context *c,
                       void (*func) (void *, const char *, ...), void *arg)
{
    char *dirs[2];
    char *defs[1];

    func(arg, "%s", c->full_path);

    dirs[0] = c->gen_dir;
    dirs[1] = NULL;
    func_pinclude_list_printf(c->full_path, func, arg, dirs, defs);
}

void language_man_build(struct language *l_uncast, struct context *c,
                      void (*func) (bool, const char *, ...))
{
    abort();
}

void language_man_link(struct language *l_uncast, struct context *c,
                     void (*func) (bool, const char *, ...),
                     bool should_install)
{
    abort();
}

void language_man_extras(struct language *l_uncast, struct context *c,
                       void *context,
                       void (*func) (void *, const char *), void *arg)
{
    func(arg, c->full_path);
}
