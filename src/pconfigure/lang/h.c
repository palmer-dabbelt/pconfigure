
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

#include "h.h"
#include "funcs.h"

#include <string.h>
#include <unistd.h>
#include <pinclude.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

/* These are the member functions for the h language. */
static struct language *language_h_search(struct language *l_uncast,
                                          struct language *parent,
                                          const char *path,
                                          struct context *c);
static const char *language_h_objname(struct language *l_uncast,
                                      void *context, struct context *c);
static void language_h_deps(struct language *l_uncast, struct context *c,
                            void (*func) (void *, const char *, ...),
                            void *arg);
static void language_h_build(struct language *l_uncast, struct context *c,
                             void (*func) (bool, const char *, ...));
static void language_h_link(struct language *l_uncast, struct context *c,
                            void (*func) (bool, const char *, ...),
                            bool should_install);
static void language_h_extras(struct language *l_uncast, struct context *c,
                              void *context,
                              void (*func) (void *, const char *), void *arg);

struct language *language_h_new(struct clopts *o, const char *name)
{
    struct language_h *l;

    if (strcmp(name, "h") != 0)
        return NULL;

    l = talloc(o, struct language_h);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "h");
    l->l.compiled = false;
    l->l.cares_about_static = false;
    l->l.compile_str = talloc_strdup(l, "");
    l->l.compile_cmd = talloc_strdup(l, "");
    l->l.link_str = talloc_strdup(l, "HC");
    l->l.link_cmd = talloc_strdup(l, "cp");
    l->l.search = &language_h_search;
    l->l.objname = &language_h_objname;
    l->l.deps = &language_h_deps;
    l->l.build = &language_h_build;
    l->l.link = &language_h_link;
    l->l.extras = &language_h_extras;

    return &(l->l);
}

struct language *language_h_search(struct language *l_uncast,
                                   struct language *parent,
                                   const char *path, struct context *c)
{
    struct language_h *l;

    l = talloc_get_type(l_uncast, struct language_h);
    if (l == NULL)
        return NULL;

    if ((strcmp(path + strlen(path) - 2, ".h") != 0)
        && (strcmp(path + strlen(path) - 4, ".h++") != 0)
        && (strcmp(path + strlen(path) - 4, ".hpp") != 0))
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->name, l_uncast->name) != 0)
        return NULL;

    if (c->parent->type != CONTEXT_TYPE_HEADER)
        return NULL;

    if (strcmp(c->parent->full_path, c->parent->link_path) != 0) {
        fprintf(stderr, "Detected two SOURCES for one HEADER\n");
        return NULL;
    }

    c->parent->link_path = talloc_strdup(c->parent, c->full_path);

#ifdef DEBUG
    fprintf(stderr, "language_h_search(): replacing '%s' with '%s'\n",
            c->link_path, c->full_path);
#endif

    return l_uncast;
}

const char *language_h_objname(struct language *l_uncast, void *context,
                               struct context *c)
{
    abort();
    return NULL;
}

void language_h_deps(struct language *l_uncast, struct context *c,
                     void (*func) (void *, const char *, ...), void *arg)
{
    char *dirs[1];
    char *defs[1];

    func(arg, "%s", c->full_path);

    dirs[0] = NULL;
    func_pinclude_list_printf(c->full_path, func, arg, dirs, defs);
}

void language_h_build(struct language *l_uncast, struct context *c,
                      void (*func) (bool, const char *, ...))
{
    abort();
}

void language_h_link(struct language *l_uncast, struct context *c,
                     void (*func) (bool, const char *, ...),
                     bool should_install)
{
    abort();
}

void language_h_extras(struct language *l_uncast, struct context *c,
                       void *context,
                       void (*func) (void *, const char *), void *arg)
{
    func(arg, c->full_path);
}
