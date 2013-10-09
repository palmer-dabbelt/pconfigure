
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

#include "funcs.h"
#include "pkgconfig.h"
#include <string.h>
#include <unistd.h>
#include <pinclude.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

/* Member functions. */
static struct language *language_pkgconfig_search(struct language *l_uncast,
                                                  struct language *parent,
                                                  const char *path);
static const char *language_pkgconfig_objname(struct language *l_uncast,
                                              void *context,
                                              struct context *c);
static void language_pkgconfig_deps(struct language *l_uncast,
                                    struct context *c,
                                    void (*func) (void *, const char *, ...),
                                    void *arg);
static void language_pkgconfig_build(struct language *l_uncast,
                                     struct context *c, void (*func) (bool,
                                                                      const
                                                                      char *,
                                                                      ...));
static void language_pkgconfig_slib(struct language *l_uncast,
                                    struct context *c, void (*func) (bool,
                                                                     const
                                                                     char *,
                                                                     ...));
static void language_pkgconfig_extras(struct language *l_uncast,
                                      struct context *c, void *context,
                                      void (*func) (void *, const char *),
                                      void *arg);

/* Manages the "-S" argument for building pkg-config files, which
 * effectively just defers the sed until later. */
struct defer_sed_args
{
    void *arg;
    void (*func) (void *, const char *, ...);
};
static int defer_sed(const char *opt, void *args_uncast);

/* This one only passes the first link string that it comes into
 * contact with, but aside from that it's like
 * "func_stringlist_each_cmd_cont()". */
struct link_func
{
    int obj_count;
    void (*func) (bool, const char *, ...);
};
static int pass_first_link_str(const char *opt, void *args_uncast);

/* Passes along calls to sed, sometimes wrapping them in a
 * subshell. */
struct pass_sed_args
{
    void (*func) (bool, const char *, ...);
};
static int pass_sed(const char *opt, void *args_uncast);

struct language *language_pkgconfig_new(struct clopts *o, const char *name)
{
    struct language_pkgconfig *l;

    if (strcmp(name, "pkgconfig") != 0)
        return NULL;

    l = talloc(o, struct language_pkgconfig);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "pkgconfig");
    l->l.compiled = false;
    l->l.compile_str = talloc_strdup(l, "");
    l->l.compile_cmd = talloc_strdup(l, "");
    l->l.link_str = talloc_strdup(l, "PKGCFG");
    l->l.link_cmd = talloc_strdup(l, "ppkgconfigc");
    l->l.search = &language_pkgconfig_search;
    l->l.objname = &language_pkgconfig_objname;
    l->l.deps = &language_pkgconfig_deps;
    l->l.build = &language_pkgconfig_build;
    l->l.slib = &language_pkgconfig_slib;
    l->l.extras = &language_pkgconfig_extras;

    return &(l->l);
}

struct language *language_pkgconfig_search(struct language *l_uncast,
                                           struct language *parent,
                                           const char *path)
{
    struct language_pkgconfig *l;

    l = talloc_get_type(l_uncast, struct language_pkgconfig);
    if (l == NULL)
        return NULL;

    if (strcmp(path + strlen(path) - 3, ".pc") != 0)
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->name, l_uncast->name) != 0)
        return NULL;

    return l_uncast;
}

const char *language_pkgconfig_objname(struct language *l_uncast,
                                       void *context, struct context *c)
{
    abort();
    return NULL;
}

void language_pkgconfig_deps(struct language *l_uncast, struct context *c,
                             void (*func) (void *, const char *, ...),
                             void *arg)
{
    struct language_pkgconfig *l;
    char *dirs[1];

    l = talloc_get_type(l_uncast, struct language_pkgconfig);
    if (l == NULL)
        return;

    {
        struct defer_sed_args dsa;
        dsa.func = func;
        dsa.arg = arg;

        stringlist_each(l->l.link_opts, &defer_sed, &dsa);
        stringlist_each(c->link_opts, &defer_sed, &dsa);
    }

    dirs[0] = NULL;
    func_pinclude_list_printf(c->full_path, func, arg, dirs);
}

void language_pkgconfig_build(struct language *l_uncast, struct context *c,
                              void (*func) (bool, const char *, ...))
{
    abort();
}

void language_pkgconfig_slib(struct language *l_uncast, struct context *c,
                             void (*func) (bool, const char *, ...))
{
    struct language_pkgconfig *l;
    void *context;

    l = talloc_get_type(l_uncast, struct language_pkgconfig);
    if (l == NULL)
        return;

    context = talloc_new(NULL);

    func(true, "echo -e \"%s\\t%s\"",
         l->l.link_str, c->full_path + strlen(c->bin_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", c->link_path);

    func(false, "cat \\");

    /* FIXME: deps() doesn't get called because this isn't compiled
     * code so we need to fake this with extras() instead.  That means
     * every pkgconfig script gets set as an object to be linked and
     * therefor gets cat'd to the end of the file.  In this case we
     * want to skip those extra files and just link the first one. */
    {
        struct link_func link_func;
        link_func.obj_count = 0;
        link_func.func = func;
        stringlist_each(c->objects, &pass_first_link_str, &link_func);
    }

    func(false, "\\ | sed 's^@@pconfigure_prefix@@^%s^g'", c->prefix);
    func(false, "\\ | sed 's^@@pconfigure_libdir@@^%s^g'", c->lib_dir);
    func(false, "\\ | sed 's^@@pconfigure_hdrdir@@^%s^g'", c->hdr_dir);

    {
        struct pass_sed_args psa;
        psa.func = func;
        stringlist_each(l->l.link_opts, &pass_sed, &psa);
        stringlist_each(c->link_opts, &pass_sed, &psa);
    }

    func(false, "\\ > %s\n", c->link_path);

    TALLOC_FREE(context);
}

void language_pkgconfig_extras(struct language *l_uncast, struct context *c,
                               void *context,
                               void (*func) (void *, const char *), void *arg)
{
    char *dirs[1];

    dirs[0] = NULL;
    func_pinclude_list_string(c->full_path, func, arg, dirs);
}

int defer_sed(const char *opt, void *args_uncast)
{
    struct defer_sed_args *args;
    args = args_uncast;

    if (strncmp(opt, "-S", 2) == 0)
        args->func(args->arg, "%s", opt + 2);

    return 0;
}

int pass_first_link_str(const char *opt, void *args_uncast)
{
    struct link_func *args;
    args = args_uncast;

    if (args->obj_count++ == 0)
        args->func(false, "\\ %s", opt);

    return 0;
}

int pass_sed(const char *opt, void *args_uncast)
{
    struct pass_sed_args *args;
    args = args_uncast;

    if (strncmp(opt, "-S", 2) == 0)
        args->func(false, "\\ | sed `cat %s`", opt + 2);
    else
        args->func(false, "\\ | sed '%s'", opt);
    return 0;
}
