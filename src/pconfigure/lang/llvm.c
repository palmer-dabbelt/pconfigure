
/*
 * Copyright (C) 2014 Palmer Dabbelt
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

#include "llvm.h"
#include "funcs.h"
#include <string.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

/* Instance methods. */
static struct language *language_llvm_search(struct language *l_uncast,
                                            struct language *parent,
                                            const char *path,
                                            struct context *c);
static void language_llvm_deps(struct language *l_uncast, struct context *c,
                               void (*func) (void *arg, const char *, ...),
                               void *arg);
static void language_llvm_build(struct language *l_uncast, struct context *c,
                                void (*func) (bool, const char *, ...));
static void language_llvm_extras(struct language *l_uncast, struct context *c,
                                void *context,
                                void (*func) (void *arg, const char *),
                                void *);

struct language *language_llvm_new(struct clopts *o, const char *name)
{
    struct language_c *l;

    if (strcmp(name, "llvm") != 0)
        return NULL;

    l = language_c_new_uc(o, "c");
    if (l == NULL)
        return NULL;

    l->l.name = talloc_strdup(l, "llvm");
    l->l.compiled = true;
    l->l.compile_str = talloc_strdup(l, "LLVM");
    l->l.compile_cmd = talloc_strdup(l, "llc");
    l->l.link_str = talloc_strdup(l, "LDLLVM");
    l->l.link_cmd = talloc_strdup(l, "${CC}");
    l->l.search = &language_llvm_search;
    l->l.build = &language_llvm_build;
    l->l.deps = &language_llvm_deps;
    l->l.extras = &language_llvm_extras;
    l->cflags = talloc_strdup(l, "$(LLVMFLAGS)");

    return &(l->l);
}

struct language *language_llvm_search(struct language *l_uncast,
                                     struct language *parent,
                                     const char *path, struct context *c)
{
    struct language_c *l;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return NULL;

    if ((strcmp(path + strlen(path) - 5, ".llvm") != 0) &&
        (strcmp(path + strlen(path) - 3, ".ll") != 0))
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->link_name, l_uncast->link_name) != 0)
        return NULL;

    return l_uncast;
}

void language_llvm_build(struct language *l_uncast, struct context *c,
                         void (*func) (bool, const char *, ...))
{
    struct language_c *l;
    void *context;
    const char *obj_path;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return;

    context = talloc_new(NULL);
    obj_path = language_objname(l_uncast, context, c);

    func(true, "echo -e \"%s\\t%s\"",
         l->l.compile_str, c->full_path + strlen(c->src_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", obj_path);

    func(false, "%s %s\\", l->l.compile_cmd, l->cflags);

    func_stringlist_each_cmd_cont(l->l.compile_opts, func);
    func_stringlist_each_cmd_cont(c->compile_opts, func);

    func(false, "\\ %s -o %s.S\n", c->full_path, obj_path);

    func(false, "$(CXX) -c %s.S -o %s", obj_path, obj_path);

    TALLOC_FREE(context);
}

void language_llvm_deps(struct language *l_uncast, struct context *c,
                        void (*func) (void *arg, const char *, ...),
                        void *arg)
{
    func(arg, "%s", c->full_path);
}

void language_llvm_extras(struct language *l_uncast, struct context *c,
                         void *context,
                         void (*func) (void *, const char *), void *arg)
{
}
