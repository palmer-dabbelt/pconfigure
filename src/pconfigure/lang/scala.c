
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

#define _XOPEN_SOURCE 500

#include "ftwfn.h"
#include "funcs.h"
#include "scala.h"
#include <ftw.h>
#include <string.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

#ifdef HAVE_CLANG
#include <clang-c/Index.h>
#else
#include "extern/clang.h"
#endif

/* Member functions. */
static struct language *language_scala_search(struct language *l_uncast,
                                              struct language *parent,
                                              const char *path,
                                              struct context *c);
static const char *language_scala_objname(struct language *l_uncast,
                                          void *context, struct context *c);
static void language_scala_deps(struct language *l_uncast, struct context *c,
                                void (*func) (void *, const char *, ...),
                                void *arg);
static void language_scala_build(struct language *l_uncast, struct context *c,
                                 void (*func) (bool, const char *, ...));
static void language_scala_link(struct language *l_uncast, struct context *c,
                                void (*func) (bool, const char *, ...),
                                bool should_install);
static void language_scala_slib(struct language *l_uncast, struct context *c,
                                void (*func) (bool, const char *, ...));
static void language_scala_extras(struct language *l_uncast,
                                  struct context *c, void *context,
                                  void (*func) (void *, const char *),
                                  void *arg);

/* Adds every file to the dependency list. */
struct ftw_args
{
    struct language_scala *l;
    void *ctx;
    void (*func) (void *, const char *, ...);
    void *arg;
};

static int ftw_add(const char *fpath, const struct stat *sb,
                   int typeflag, struct FTW *ftwbuf, void *arg);

struct language *language_scala_new(struct clopts *o, const char *name)
{
    struct language_scala *l;

    if (strcmp(name, "scala") != 0)
        return NULL;

    l = talloc(o, struct language_scala);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "scala");
    l->l.link_name = talloc_strdup(l, "scala");
    l->l.compile_str = talloc_strdup(l, "SC");
    l->l.compile_cmd = talloc_strdup(l, "pscalac");
    l->l.link_str = talloc_strdup(l, "SLD");
    l->l.link_cmd = talloc_strdup(l, "pscalald");
    l->l.so_ext = talloc_strdup(l, "jar");
    l->l.compiled = true;
    l->l.search = &language_scala_search;
    l->l.objname = &language_scala_objname;
    l->l.deps = &language_scala_deps;
    l->l.build = &language_scala_build;
    l->l.link = &language_scala_link;
    l->l.slib = &language_scala_slib;
    l->l.extras = &language_scala_extras;

    l->deps = stringlist_new(l);

    return &(l->l);
}

struct language *language_scala_search(struct language *l_uncast,
                                       struct language *parent,
                                       const char *path, struct context *c)
{
    struct language_scala *l;

    l = talloc_get_type(l_uncast, struct language_scala);
    if (l == NULL)
        return NULL;

    if (strlen(path) <= 6)
        return NULL;

    if (strcmp(path + strlen(path) - 6, ".scala") != 0)
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->link_name, l_uncast->link_name) != 0)
        return NULL;

    return l_uncast;
}

const char *language_scala_objname(struct language *l_uncast, void *context,
                                   struct context *c)
{
    char *o;
    const char *compileopts_hash, *langopts_hash;
    struct language_scala *l;
    void *subcontext;

    l = talloc_get_type(l_uncast, struct language_scala);
    if (l == NULL)
        return NULL;

    subcontext = talloc_new(NULL);
    compileopts_hash = stringlist_hashcode(c->compile_opts, subcontext);
    langopts_hash = stringlist_hashcode(l->l.compile_opts, subcontext);

    /* This should be checked higher up in the stack, but just make sure */
    assert(c->full_path[strlen(c->src_dir)] == '/');

    o = talloc_asprintf(context, "%s/%s/%s-%s.jar",
                        c->obj_dir,
                        c->full_path, compileopts_hash, langopts_hash);

    TALLOC_FREE(subcontext);
    return o;
}

void language_scala_deps(struct language *l_uncast, struct context *c,
                         void (*func) (void *, const char *, ...), void *arg)
{
    void *ctx;
    struct language_scala *l;
    const char *dir;

    l = talloc_get_type(l_uncast, struct language_scala);
    if (l == NULL)
        abort();

    ctx = talloc_new(l);

    dir = c->full_path + strlen(c->full_path) - 1;
    while (*dir != '/' && dir != c->full_path)
        dir--;

    dir = talloc_strndup(ctx, c->full_path, dir - c->full_path);

    /* FIXME: I can't properly handle Scala dependencies, so I just
     * build every Scala file in the same directory as the current
     * Scala file.  This is probably very bad... */
    {
        struct ftw_args fa;
        fa.l = l;
        fa.ctx = ctx;
        fa.func = func;
        fa.arg = arg;
        aftw(dir, &ftw_add, 16, FTW_DEPTH, &fa);
    }

    TALLOC_FREE(ctx);

    return;
}

void language_scala_build(struct language *l_uncast, struct context *c,
                          void (*func) (bool, const char *, ...))
{
    struct language_scala *l;
    void *context;
    const char *obj_path;
    const char *compile_str;

    l = talloc_get_type(l_uncast, struct language_scala);
    if (l == NULL)
        return;

    context = talloc_new(NULL);
    obj_path = language_objname(l_uncast, context, c);

    compile_str = l->l.compile_str;

    func(true, "echo -e \"%s\\t%s\"",
         compile_str, c->full_path + strlen(c->src_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", obj_path);

    func(false, "%s\\", l->l.compile_cmd);

    func_stringlist_each_cmd_cont(l->l.compile_opts, func);
    func_stringlist_each_cmd_cont(c->compile_opts, func);
    func_stringlist_each_cmd_cont(l->deps, func);

    func(false, "\\ -o %s\n", obj_path);

    TALLOC_FREE(context);
}

void language_scala_link(struct language *l_uncast, struct context *c,
                         void (*func) (bool, const char *, ...),
                         bool should_install)
{
    struct language_scala *l;
    void *context;
    const char *link_path;

    l = talloc_get_type(l_uncast, struct language_scala);
    if (l == NULL)
        return;

    if (should_install == false)
        link_path = c->link_path;
    else
        link_path = c->link_path_install;

    context = talloc_new(NULL);

    func(true, "echo -e \"%s\\t%s\"",
         l->l.link_str, c->full_path + strlen(c->bin_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", link_path);

    func(false, "%s -o %s", l->l.link_cmd, link_path);
    func(false, "\\");

    func_stringlist_each_cmd_cont(l->l.link_opts, func);
    func_stringlist_each_cmd_cont(c->link_opts, func);
    func_stringlist_each_cmd_cont(c->objects, func);
    func_stringlist_each_cmd_lcont(c->libraries, func);

    func(false, "\\\n");

    TALLOC_FREE(context);
}

void language_scala_slib(struct language *l_uncast, struct context *c,
                         void (*func) (bool, const char *, ...))
{
    struct language_scala *l;
    void *context;
    const char *link_path;

    l = talloc_get_type(l_uncast, struct language_scala);
    if (l == NULL)
        return;

    link_path = c->link_path;

    context = talloc_new(NULL);

    func(true, "echo -e \"%s\\t%s\"",
         l->l.link_str, c->full_path + strlen(c->bin_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", link_path);

    func(false, "%s -shared -o %s", l->l.link_cmd, link_path);
    func(false, "\\");

    func_stringlist_each_cmd_cont(l->l.link_opts, func);
    func_stringlist_each_cmd_cont(c->link_opts, func);
    func_stringlist_each_cmd_cont(c->objects, func);
    func_stringlist_each_cmd_lcont(c->libraries, func);

    func(false, "\\\n");

    TALLOC_FREE(context);
}

void language_scala_extras(struct language *l_uncast, struct context *c,
                           void *context,
                           void (*func) (void *arg, const char *), void *arg)
{
    /* FIXME: Scala doesn't seem to support incremental compilation,
     * so we can't really handle the whole extras thing.  I just
     * depend on every scala file, which is probably not the best. */
}

int ftw_add(const char *path, const struct stat *sb,
            int typeflag, struct FTW *ftwbuf, void *args_uncast)
{
    char *copy;
    struct language_scala *l;
    void *ctx;
    void (*func) (void *, const char *, ...);
    void *arg;

    {
        struct ftw_args *args;
        args = args_uncast;
        l = args->l;
        ctx = args->ctx;
        func = args->func;
        arg = args->arg;
    }

    if (strcmp(path + strlen(path) - 6, ".scala") == 0) {
        copy = talloc_strdup(ctx, path);
        func(arg, "%s", copy);
        stringlist_add(l->deps, copy);
    }

    return 0;
}
