
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

#include "flo.h"
#include "ftwfn.h"
#include "funcs.h"
#include "../languagelist.h"
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

/* FIXME: This allows me to access the global langauge list, it's a
 * huge hack! */
extern struct languagelist *ll;

/* Member functions. */
static struct language *language_flo_search(struct language *l_uncast,
                                            struct language *parent,
                                            const char *path,
                                            struct context *c);
static const char *language_flo_objname(struct language *l_uncast,
                                        void *context, struct context *c);
static void language_flo_deps(struct language *l_uncast, struct context *c,
                              void (*func) (void *, const char *, ...),
                              void *arg);
static void language_flo_build(struct language *l_uncast,
                               struct context *c, void (*func) (bool,
                                                                const char
                                                                *, ...));
static void language_flo_link(struct language *l_uncast, struct context *c,
                              void (*func) (bool, const char *, ...),
                              bool should_install);
static void language_flo_slib(struct language *l_uncast, struct context *c,
                              void (*func) (bool, const char *, ...));
static void language_flo_extras(struct language *l_uncast,
                                struct context *c, void *context,
                                void (*func) (void *, const char *),
                                void *arg);
static void language_flo_quirks(struct language *l_uncast,
                                struct context *c, struct makefile *mf);

/* Adds every file to the dependency list. */
struct ftw_args
{
    struct language_flo *l;
    void *ctx;
    void (*func) (void *, const char *, ...);
    void *arg;
};

static int ftw_add(const char *fpath, const struct stat *sb,
                   int typeflag, struct FTW *ftwbuf, void *arg);

/* Checks if a given library is a "*.so" and eats it, otherwise passes
 * it along to the given function. */
struct eat_so_args
{
    void (*func) (bool, const char *, ...);
};
static int eat_so(const char *lib, void *args_uncast);

/* I think there probably should be a cleaner way to do this, but I'm
 * not entirely sure how to go about it. */
struct jarlib_args
{
    struct context *c;
    void (*func) (void *, const char *, ...);
    void *arg;
};
static int jarlib(const char *lib, void *args_uncast);

struct language *language_flo_new(struct clopts *o, const char *name)
{
    struct language_flo *l;

    if (strcmp(name, "flo") != 0)
        return NULL;

    l = talloc(o, struct language_flo);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "flo");
    l->l.link_name = talloc_strdup(l, "flo");
    l->l.compile_str = talloc_strdup(l, "ChFlo");
    l->l.compile_cmd = talloc_strdup(l, "cp");
    l->l.link_str = talloc_strdup(l, "ChFlo");
    l->l.link_cmd = talloc_strdup(l, "cp");
    l->l.so_ext = talloc_strdup(l, "flo");
    l->l.so_ext_canon = talloc_strdup(l, "flo");
    l->l.a_ext = talloc_strdup(l, "flo");
    l->l.a_ext_canon = talloc_strdup(l, "flo");
    l->l.compiled = true;
    l->l.search = &language_flo_search;
    l->l.objname = &language_flo_objname;
    l->l.deps = &language_flo_deps;
    l->l.build = &language_flo_build;
    l->l.link = &language_flo_link;
    l->l.slib = &language_flo_slib;
    l->l.extras = &language_flo_extras;
    l->l.quirks = &language_flo_quirks;

    return &(l->l);
}

struct language *language_flo_search(struct language *l_uncast,
                                     struct language *parent,
                                     const char *path, struct context *c)
{
    struct language_flo *l;

    if (c == NULL)
        return NULL;

    if (c->type != CONTEXT_TYPE_SOURCE)
        return NULL;

    if (c->parent == NULL)
        return NULL;

    /* Flo can only build .scala files that are attached to a .flo
     * binary. */
    if (strcmp(c->parent->full_path + strlen(c->parent->full_path) - 4,
               ".flo") != 0)
        return NULL;

    l = talloc_get_type(l_uncast, struct language_flo);
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

const char *language_flo_objname(struct language *l_uncast, void *context,
                                 struct context *c)
{
    char *o;
    const char *compileopts_hash, *langopts_hash;
    struct language_flo *l;
    void *subcontext;

    l = talloc_get_type(l_uncast, struct language_flo);
    if (l == NULL)
        return NULL;

    subcontext = talloc_new(NULL);
    compileopts_hash = stringlist_hashcode(c->compile_opts, subcontext);
    langopts_hash = stringlist_hashcode(l->l.compile_opts, subcontext);

    /* This should be checked higher up in the stack, but just make sure */
    assert(c->full_path[strlen(c->src_dir)] == '/');

    o = talloc_asprintf(context, "%s/%s/%s-%s-%s-chisel_flo.o",
                        c->obj_dir,
                        c->full_path, compileopts_hash, langopts_hash,
                        c->shared_target ? "shared" : "static");

    TALLOC_FREE(subcontext);
    return o;
}

void language_flo_deps(struct language *l_uncast, struct context *c,
                       void (*func) (void *, const char *, ...), void *arg)
{
    void *ctx;
    struct language_flo *l;
    const char *dir;

    l = talloc_get_type(l_uncast, struct language_flo);
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

    {
        struct jarlib_args jla;
        jla.func = func;
        jla.c = c;
        jla.arg = arg;
        stringlist_each(c->libraries, &jarlib, &jla);
    }

    TALLOC_FREE(ctx);

    return;
}

void language_flo_build(struct language *l_uncast, struct context *c,
                        void (*func) (bool, const char *, ...))
{
    struct language_flo *l;
    void *context;
    const char *obj_path;
    const char *compile_str;
    char *design;
    const char *last_source;

    l = talloc_get_type(l_uncast, struct language_flo);
    if (l == NULL)
        return;

    context = talloc_new(NULL);
    obj_path = language_objname(l_uncast, context, c);

    compile_str = l->l.compile_str;

    func(true, "echo -e \"%s\\t%s\"",
         compile_str, c->full_path + strlen(c->src_dir) + 1);

    /* Search for the design name, which is necessary because we can't
     * know this for a while. */
    design = NULL;

    {
        const char *found;
        found = stringlist_search_start(l->l.compile_opts, "-d", context);

        if (found != NULL)
            design = talloc_strdup(context, found + 2);
    }

    {
        const char *found;
        found = stringlist_search_start(c->compile_opts, "-d", context);

        if (found != NULL)
            design = talloc_strdup(context, found + 2);
    }

    /* Compile the scala sources */
    func(false, "pscalac `ppkg-config chisel --libs`\\");
    func(false, "\\ -L %s", c->lib_dir);
    last_source = c->full_path;

    {
        struct eat_so_args esa;
        esa.func = func;
        stringlist_each(c->libraries, &eat_so, &esa);
    }

    if (last_source == NULL) {
        fprintf(stderr, "flo compiler called with no sources!\n");
    }
    func(false, "\\ $$(find `dirname %s` -iname *.scala)", last_source);
    func(false, "\\ -o %s.d/obj.jar\n", obj_path);

    /* Add a flag that tells Scala how to start up */
    func(false, "pscalald `ppkg-config chisel --libs`\\");
    func(false, "\\ -L %s", c->lib_dir);
    func_stringlist_each_cmd_lcont(c->libraries, func);
    func(false, "\\ -o %s.d/obj.bin %s.d/obj.jar\n", obj_path, obj_path);

    /* Actually run the resulting Chisel binary to produce some
     * DREAMER code */
    func(false, "%s.d/obj.bin --targetDir %s.d/gen --backend flo >& /dev/null"
         " || %s.d/obj.bin --targetDir %s.d/gen --backend flo",
         obj_path, obj_path, obj_path, obj_path);

    /* Finally, copy the resulting .flo file out to somewhere
     * pconfigure expects. */
    func(false, "cp %s.d/gen/%s.flo %s", obj_path, design, obj_path);

    TALLOC_FREE(context);
}

void language_flo_link(struct language *l_uncast, struct context *c,
                       void (*func) (bool, const char *, ...),
                       bool should_install)
{
    struct language_flo *l;
    void *context;
    const char *link_path;

    l = talloc_get_type(l_uncast, struct language_flo);
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

    func(false, "cat \\");
    func_stringlist_each_cmd_cont(c->objects, func);
    func(false, "\\ > %s\n", link_path);

    TALLOC_FREE(context);
}

void language_flo_slib(struct language *l_uncast, struct context *c,
                       void (*func) (bool, const char *, ...))
{
}

void language_flo_extras(struct language *l_uncast, struct context *c,
                         void *context,
                         void (*func) (void *, const char *), void *arg)
{
    /* FIXME: Scala doesn't seem to support incremental compilation,
     * so we can't really handle the whole extras thing.  I just
     * depend on every flo file, which is probably not the best. */
}

void language_flo_quirks(struct language *l_uncast,
                         struct context *c, struct makefile *mf)
{
}

int ftw_add(const char *path, const struct stat *sb,
            int typeflag, struct FTW *ftwbuf, void *args_uncast)
{
    char *copy;
    void *ctx;
    void (*func) (void *, const char *, ...);
    void *arg;

    {
        struct ftw_args *args;
        args = args_uncast;
        ctx = args->ctx;
        func = args->func;
        arg = args->arg;
    }

    if (strcmp(path + strlen(path) - 6, ".scala") == 0) {
        copy = talloc_strdup(ctx, path);
        func(arg, "%s", copy);
    }

    return 0;
}

int eat_so(const char *lib, void *args_uncast)
{
    struct eat_so_args *args;
    args = args_uncast;

    if (strcmp(lib + strlen(lib) - 3, ".so") == 0)
        return 0;

    args->func(false, "\\ -l %s", lib);
    return 0;
}

int jarlib(const char *lib, void *args_uncast)
{
    struct context *c;
    char *str;
    struct jarlib_args *args;
    void *arg;

    args = args_uncast;
    c = args->c;
    arg = args->arg;

    str = talloc_asprintf(NULL, "%s/lib%s.jar", c->lib_dir, lib);
    args->func(arg, "%s", str);

    TALLOC_FREE(str);
    return 0;
}
