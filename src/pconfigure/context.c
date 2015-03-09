
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

#include "context.h"
#include "stringlist.h"
#include "liblist.h"
#include "pass_vadd.h"
#include "pass_vcmd.h"
#include "pass_cspush.h"
#include <assert.h>
#include <string.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

#ifndef DEFAULT_PREFIX
#define DEFAULT_PREFIX "/usr/local"
#endif

/* This holds a list of the dependencies of every library in the
 * system. */
static void *lib_deps_ctx = NULL;
static struct liblist *lib_deps = NULL;

/* Here's a bit of a hack: these come from main and are set as part of
 * the commandline arguments. */
extern bool found_binary;
extern struct clopts *o;

static int context_binary_destructor(struct context *c);
static int context_library_destructor(struct context *c);
static int context_header_destructor(struct context *c);
static int context_source_destructor(struct context *c);
static int context_test_destructor(struct context *c);

static void context_destructor(void);

struct context *context_new_defaults(struct clopts *o, void *context,
                                     struct makefile *mf,
                                     struct languagelist *ll,
                                     struct contextstack *s)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_DEFAULTS;
    c->parent = NULL;
    c->test_parent = NULL;
    c->bin_dir = talloc_strdup(c, "bin");
    c->lib_dir = talloc_strdup(c, "lib");
    c->hdr_dir = talloc_asprintf(c, "%sinclude", o->source_path);
    c->obj_dir = talloc_strdup(c, "obj");
    c->src_dir = talloc_asprintf(c, "%ssrc", o->source_path);
    c->chk_dir = talloc_strdup(c, "check");
    c->tst_dir = talloc_asprintf(c, "%stest", o->source_path);
    c->gen_dir = talloc_strdup(c, "obj/proc");
    c->prefix = talloc_strdup(c, DEFAULT_PREFIX);
    c->libexec_dir = talloc_strdup(c, "libexec");
    c->compile_opts = stringlist_new(c);
    c->link_opts = stringlist_new(c);
    c->shared_target = false;
    c->mf = talloc_reference(c, mf);
    c->ll = talloc_reference(c, ll);
    c->s = s;
    c->language = NULL;
    c->autodeps = true;

    return c;
}

struct context *context_new_binary(struct context *parent, void *context,
                                   const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_BINARY;
    c->parent = c;
    c->test_parent = NULL;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->shared_target = false;
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_new(c);
    c->testdir = talloc_asprintf(c, "%s/%s", c->tst_dir, called_path);
    c->autodeps = parent->autodeps;

    c->called_path = talloc_strdup(c, called_path);
    c->full_path = talloc_asprintf(c, "%s/%s", c->bin_dir, called_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_binary_destructor);

    return c;
}

int context_binary_destructor(struct context *c)
{
    struct language *l;
    char *tmp;
    void *context;
    const char *hash_langlinkopts, *hash_linkopts, *hash_objs;

    assert(c->type == CONTEXT_TYPE_BINARY);
#ifdef DEBUG
    fprintf(stderr, "context_binary_destructor('%s')\n", c->full_path);
#endif

    l = c->language;
    assert(l != NULL);

    context = talloc_new(NULL);

#ifdef DEBUG
    stringlist_fprintf(c->objects, stderr, "obj: %s\n");
#endif

    hash_langlinkopts = stringlist_hashcode(c->language->link_opts, context);
    hash_linkopts = stringlist_hashcode(c->link_opts, context);
    hash_objs = stringlist_hashcode(c->objects, context);
    talloc_unlink(c, (char *)c->link_path);
    c->link_path = talloc_asprintf(c, "%s/%s/%s-%s-%s.bin",
                                   c->obj_dir, c->full_path,
                                   hash_langlinkopts, hash_linkopts,
                                   hash_objs);
    c->link_path_install = talloc_asprintf(c, "%s/%s/%s-%s-%s.ins/%s",
                                           c->obj_dir, c->full_path,
                                           hash_langlinkopts, hash_linkopts,
                                           hash_objs, c->full_path);

    makefile_add_targets(c->mf, c->full_path);
    makefile_add_all(c->mf, c->full_path);
    makefile_add_all_install(c->mf, c->link_path_install);

    /* Creates a "dummy" target that just copies over the actual binary */
    makefile_create_target(c->mf, c->full_path);
    makefile_start_deps(c->mf);
    makefile_add_dep(c->mf, "%s", c->link_path);
    makefile_add_dep(c->mf, "Makefile");
    makefile_end_deps(c->mf);
    makefile_start_cmds(c->mf);
    makefile_nam_cmd(c->mf, "echo \"CP\t%s\"",
                     c->full_path + strlen(c->bin_dir) + 1);
    makefile_add_cmd(c->mf, "mkdir -p `dirname %s`", c->full_path);
    makefile_add_cmd(c->mf, "cp %s %s", c->link_path, c->full_path);
    makefile_end_cmds(c->mf);

    /* Does the actual linking with hashes of the arguments */
    makefile_create_target(c->mf, c->link_path);

    makefile_start_deps(c->mf);

    makefile_addl_dep(c->mf, c->objects, "%%s");
    makefile_addl_dep(c->mf, c->libraries, "%s/lib%%s.%s",
                      c->lib_dir, l->so_ext);

    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    language_link_pass_vcmd(l, c, false);
    makefile_end_cmds(c->mf);

    /* Link a second time, but with the install path now */
    makefile_create_target(c->mf, c->link_path_install);

    makefile_start_deps(c->mf);

    makefile_addl_dep(c->mf, c->objects, "%%s");
    makefile_addl_dep(c->mf, c->libraries, "%s/lib%%s.%s",
                      c->lib_dir, l->so_ext);

    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    language_link_pass_vcmd(l, c, true);
    makefile_end_cmds(c->mf);

    /* There is an install/uninstall target */
    tmp = talloc_asprintf(context, "echo -e \"INS\\t%s\"", c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp = talloc_asprintf(context,
                          "mkdir -p `dirname $D/\"%s/%s\"` >& /dev/null || true",
                          c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp =
        talloc_asprintf(context,
                        "install -m a=rx %s $D/`dirname \"%s/%s\"`",
                        c->link_path_install, c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);

    tmp = talloc_asprintf(context, "%s/%s", c->prefix, c->full_path);
    makefile_add_uninstall(c->mf, tmp);

    makefile_add_distclean(c->mf, c->bin_dir);

    TALLOC_FREE(context);
    return 0;
}

struct context *context_new_library(struct context *parent, void *context,
                                    const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_LIBRARY;
    c->parent = c;
    c->test_parent = NULL;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->shared_target = true;
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_new(c);
    c->testdir = talloc_asprintf(c, "%s/%s", c->tst_dir, called_path);
    c->autodeps = parent->autodeps;

    c->called_path = talloc_strdup(c, called_path);
    c->full_path = talloc_asprintf(c, "%s/%s", c->lib_dir, called_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_library_destructor);

    return c;
}

int context_library_destructor(struct context *c)
{
    struct language *l;
    char *tmp;
    void *context;
    const char *hash_langlinkopts, *hash_linkopts, *hash_objs;
    char *sname;

    assert(c->type == CONTEXT_TYPE_LIBRARY);

#ifdef DEBUG
    fprintf(stderr, "context_library_destructor('%s')\n", c->full_path);
#endif

    l = c->language;
    assert(l != NULL);

    context = talloc_new(NULL);

    /* Checks if the library name doesn't match and attempts to
     * correct it. */
    {
        char *new_name;
        char *old_name;
        char *ext;

        old_name = talloc_strdup(context, c->full_path);

        if (strstr(old_name, ".") == NULL)
            abort();

        if (strcmp(strstr(old_name, ".") + 1, c->language->so_ext_canon) == 0)
            c->shared_target = true;
        else if (strcmp(strstr(old_name, ".") + 1, c->language->a_ext_canon)
                 == 0)
            c->shared_target = false;
        else
            abort();

        strstr(old_name, ".")[0] = '\0';

        ext = c->shared_target ? c->language->so_ext : c->language->a_ext;
        new_name = talloc_asprintf(c, "%s.%s", old_name, ext);

        c->full_path = new_name;
    }

#ifdef DEBUG
    stringlist_fprintf(c->objects, stderr, "%s\n");
#endif

    hash_langlinkopts = stringlist_hashcode(c->language->link_opts, context);
    hash_linkopts = stringlist_hashcode(c->link_opts, context);
    hash_objs = stringlist_hashcode(c->objects, context);
    talloc_unlink(c, (char *)c->link_path);
    c->link_path = talloc_asprintf(c, "%s/%s/%s-%s-%s-shared.%s",
                                   c->obj_dir, c->full_path,
                                   hash_langlinkopts, hash_linkopts,
                                   hash_objs, c->language->so_ext);

    makefile_add_targets(c->mf, c->full_path);
    makefile_add_all(c->mf, c->full_path);

    /* Creates a "dummy" target that just copies over the actual binary */
    makefile_create_target(c->mf, c->full_path);
    makefile_start_deps(c->mf);
    makefile_add_dep(c->mf, "%s", c->link_path);
    makefile_add_dep(c->mf, "Makefile");
    makefile_end_deps(c->mf);
    makefile_start_cmds(c->mf);
    makefile_nam_cmd(c->mf, "echo \"CP\t%s\"",
                     c->full_path + strlen(c->lib_dir) + 1);
    makefile_add_cmd(c->mf, "mkdir -p `dirname %s`", c->full_path);
    makefile_add_cmd(c->mf, "cp %s %s", c->link_path, c->full_path);
    makefile_end_cmds(c->mf);

    /* Does the actual linking with hashes of the arguments */
    makefile_create_target(c->mf, c->link_path);

    makefile_start_deps(c->mf);

    makefile_addl_dep(c->mf, c->objects, "%%s");

    /* If the language isn't compiled then we won't detect any changes
     * when we try and build it -- it'll just get copied.  In this
     * case we're just going to force a dependency on the Makefile, as
     * that'll ensure it gets built. */
    if (!language_needs_compile(l, c)) {
        makefile_add_dep(c->mf, "Makefile");
        language_deps_vadd_dep(l, c, c->mf);
    }

    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    language_slib_pass_vcmd(l, c);
    makefile_end_cmds(c->mf);

    /* There is an install/uninstall target */
    tmp = talloc_asprintf(context, "echo -e \"INS\\t%s\"", c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp = talloc_asprintf(context,
                          "mkdir -p `dirname $D\"%s/%s\"` >& /dev/null || true",
                          c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp =
        talloc_asprintf(context,
                        "install -m a=r %s $D/`dirname \"%s/%s\"`",
                        c->full_path, c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);

    tmp = talloc_asprintf(context, "%s/%s", c->prefix, c->full_path);
    makefile_add_uninstall(c->mf, tmp);

    makefile_add_distclean(c->mf, c->lib_dir);

    /* Add this library to the big global list of libraries.  The idea
     * here is that we can handle recursive library dependencies this
     * way. */
    sname = talloc_strndup(context, c->called_path + 3,
                           strstr(c->called_path + 3, ".")
                           - (c->called_path + 3));

    if (lib_deps == NULL) {
        lib_deps_ctx = talloc_init("context_library_destructor(): lib_deps");
        atexit(&context_destructor);
        lib_deps = liblist_new(lib_deps_ctx);
    }

    liblist_add(lib_deps, sname);

    stringlist_add_to_liblist(c->libraries, lib_deps, sname);

    TALLOC_FREE(context);
    return 0;
}

struct context *context_new_header(struct context *parent, void *context,
                                   const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_HEADER;
    c->parent = c;
    c->test_parent = NULL;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->shared_target = false;
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_new(c);
    c->autodeps = parent->autodeps;

    c->called_path = talloc_strdup(c, called_path);
    c->full_path = talloc_asprintf(c, "%s/%s", c->hdr_dir, called_path);
    c->link_path = talloc_strdup(c, c->full_path);
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_header_destructor);

    return c;
}

int context_header_destructor(struct context *c)
{
    char *tmp;
    void *context;

    context = talloc_new(c);

    assert(c->type == CONTEXT_TYPE_HEADER);
#ifdef DEBUG
    fprintf(stderr, "context_header_destructor('%s')\n", c->full_path);
#endif

    /* There is an install/uninstall target */
    tmp = talloc_asprintf(context, "echo -e \"INS\\t%s\"", c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp = talloc_asprintf(context,
                          "mkdir -p `dirname $D/\"%s/%s\"` >& /dev/null || true",
                          c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp =
        talloc_asprintf(context,
                        "install -m a=r %s $D/`dirname \"%s/%s\"`",
                        c->link_path, c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);

    tmp = talloc_asprintf(context, "%s/%s", c->prefix, c->full_path);
    makefile_add_uninstall(c->mf, tmp);

    TALLOC_FREE(c);

    return 0;
}

struct context *context_new_source(struct context *parent, void *context,
                                   const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_SOURCE;
    c->parent = parent->parent;
    c->test_parent = NULL;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->shared_target = parent->shared_target;
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_new(c);
    c->autodeps = parent->autodeps;

    c->called_path = talloc_strdup(c, called_path);
    c->full_path = talloc_asprintf(c, "%s/%s", c->src_dir, called_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_source_destructor);

    return c;
}

struct context *context_new_fullsrc(struct context *parent, void *context,
                                    const char *full_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_SOURCE;
    c->parent = parent->parent;
    c->test_parent = NULL;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->shared_target = parent->shared_target;
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_new(c);
    c->autodeps = parent->autodeps;

    c->called_path = NULL;
    c->full_path = talloc_strdup(c, full_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_source_destructor);

    return c;
}

int context_source_destructor(struct context *c)
{
    struct language *l;
    void *context;
    const char *obj_name;

    assert(c->type == CONTEXT_TYPE_SOURCE);
#ifdef DEBUG
    fprintf(stderr, "context_source_destructor('%s', '%s')\n",
            c->full_path, c->parent->full_path);
#endif

    /* Try to find a language that's compatible with the language already used
     * in this binary, and is compatible with this current source file. */
    l = languagelist_search(c->ll, c->parent->language, c->full_path, c);
    if (l == NULL) {
        fprintf(stderr, "No language found for '%s'\n", c->full_path);

        if ((c->parent == NULL) || (c->parent->language == NULL))
            abort();

        fprintf(stderr, "Parent language is '%s', from '%s'\n",
                c->parent->language->name, c->parent->full_path);
        abort();
    }
    c->parent->language = l;
#ifdef DEBUG
    fprintf(stderr, "\tc->parent->language->name: '%s'\n",
            c->parent->language->name);
#endif

    /* Try and figure out if the grandparent of this code should be a
     * shared or static library. */
    if (l->cares_about_static == true) {
        struct context *lc;

        lc = c;
        while (lc != NULL) {
            if (lc->type == CONTEXT_TYPE_LIBRARY)
                break;

            if (lc->parent == lc) {
                lc = NULL;
                break;
            }

            lc = lc->parent;
        }

        /* It's very possible we ended up with something that
         * _doesn't_ target a library, which is perfectly fine. */
        if (lc != NULL) {
            char *ext;

            ext = strstr(lc->full_path, ".");
            if (ext == NULL)
                abort();
            ext++;

            if (strcmp(ext, lc->language->so_ext_canon) == 0)
                c->shared_target = true;
            else if (strcmp(ext, lc->language->a_ext_canon) == 0)
                c->shared_target = false;
            else
                abort();
        }
    }

    /* We need to allocate some temporary memory */
    context = talloc_new(NULL);

    /* Some languages don't need to be compiled (just linked) so we skip the
     * entire compiling phase. */
    if (language_needs_compile(l, c) == true) {
        /* This is the name that our code will be compiled into.  This must
         * succeed, as we just checked that it's necessary. */
        obj_name = language_objname(l, context, c);
        assert(obj_name != NULL);

        /* This handles half of the whole "--binname --objname" stuff,
         * which is why it's so messy! */
        if (found_binary && c->called_path != NULL) {
            if (strcmp(c->called_path, o->srcname) == 0) {
                printf("%s\n", obj_name);
                talloc_disable_null_tracking();
                exit(0);
            }
        }

        /* If we've already built this dependency, then it's not necessary to
         * add it to the build list again, so skip it. */
        if (!stringlist_include(c->mf->targets, obj_name)) {
            makefile_add_targets(c->mf, obj_name);
            makefile_create_target(c->mf, obj_name);

            makefile_start_deps(c->mf);
            language_deps_vadd_dep(l, c, c->mf);
            makefile_end_deps(c->mf);

            makefile_start_cmds(c->mf);
            language_build_pass_vcmd(l, c);
            makefile_end_cmds(c->mf);

            makefile_add_targets(c->mf, obj_name);
            makefile_add_clean(c->mf, obj_name);
            makefile_add_cleancache(c->mf, c->obj_dir);
        }
    } else {
        /* The "objects" for languages that aren't compiled are really just the
         * included sources. */
        obj_name = talloc_reference(context, c->full_path);
    }

    /* Adds every "extra" (which is defined as any other sources that should be 
     * linked in as a result of this SOURCES += line) to the stack. */
    if (stringlist_include(c->parent->objects, obj_name) == false) {
        language_extras_pass_cs_push_fs(l, c, context, c->s);
        stringlist_add(c->parent->objects, obj_name);
    }

    /* Run some language-specific quirks here */
    language_quirks(l, c, c->mf);

    /* Everything succeeded! */
    TALLOC_FREE(context);
    return 0;
}

struct context *context_new_test(struct context *parent, void *context,
                                 const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_TEST;
    c->parent = c;
    c->test_parent = parent;
    c->bin_dir = talloc_reference(c, parent->chk_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_asprintf(c, "%s/%s", parent->tst_dir,
                                 parent->called_path);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->shared_target = false;
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_copy(parent->testdeps, c);
    c->testdir = talloc_strdup(c, parent->testdir);
    c->src_dir = talloc_strdup(c, parent->testdir);
    c->autodeps = parent->autodeps;

    c->called_path = talloc_strdup(c, called_path);
    c->full_path = talloc_asprintf(c, "%s/%s/%s", c->bin_dir,
                                   parent->called_path, called_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_test_destructor);

    return c;
}

int context_test_destructor(struct context *c)
{
    struct language *l;
    void *context;
    const char *hash_langlinkopts, *hash_linkopts, *hash_objs;

    assert(c->type == CONTEXT_TYPE_TEST);
#ifdef DEBUG
    fprintf(stderr, "context_test_destructor('%s')\n", c->full_path);
#endif

    l = c->language;
    assert(l != NULL);

    context = talloc_new(NULL);

#ifdef DEBUG
    stringlist_fprintf(c->objects, stderr, "obj: %s\n");
#endif

    hash_langlinkopts = stringlist_hashcode(c->language->link_opts, context);
    hash_linkopts = stringlist_hashcode(c->link_opts, context);
    hash_objs = stringlist_hashcode(c->objects, context);
    talloc_unlink(c, (char *)c->link_path);
    c->link_path = talloc_asprintf(c, "%s/%s/%s-%s-%s.bin",
                                   c->obj_dir, c->full_path,
                                   hash_langlinkopts, hash_linkopts,
                                   hash_objs);
    c->link_path_install = talloc_asprintf(c, "%s/%s/%s-%s-%s.ins/%s",
                                           c->obj_dir, c->full_path,
                                           hash_langlinkopts, hash_linkopts,
                                           hash_objs, c->full_path);

    makefile_add_targets(c->mf, c->full_path);
    makefile_add_check(c->mf, c->full_path);

    /* Run the test, producing a tarball with the results. */
    makefile_create_target(c->mf, c->full_path);
    makefile_start_deps(c->mf);
    makefile_add_dep(c->mf, "%s", c->test_parent->full_path);
    makefile_add_dep(c->mf, "%s", c->link_path);
    makefile_addl_dep(c->mf, c->testdeps, "%%s");
    makefile_end_deps(c->mf);
    makefile_start_cmds(c->mf);
    makefile_nam_cmd(c->mf, "echo \"TEST\t%s\"",
                     c->full_path + strlen(c->chk_dir) + 1);
    makefile_add_cmd(c->mf, "mkdir -p `dirname %s`", c->full_path);
    makefile_add_cmd(c->mf, "ptest --test %s --out %s --bin %s",
                     c->link_path, c->full_path, c->test_parent->full_path);
    makefile_end_cmds(c->mf);

    /* Does the actual linking with hashes of the arguments */
    makefile_create_target(c->mf, c->link_path);

    makefile_start_deps(c->mf);
    makefile_addl_dep(c->mf, c->objects, "%%s");
    makefile_addl_dep(c->mf, c->libraries, "%s/lib%%s.%s",
                      c->lib_dir, l->so_ext);
    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    language_link_pass_vcmd(l, c, false);
    makefile_end_cmds(c->mf);

    makefile_add_distclean(c->mf, c->chk_dir);

    TALLOC_FREE(context);
    return 0;
}

struct context *context_new_libexec(struct context *parent,
                                    void *context, const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_BINARY;
    c->parent = c;
    c->test_parent = NULL;
    c->bin_dir = talloc_reference(c, parent->libexec_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->chk_dir = talloc_reference(c, parent->chk_dir);
    c->tst_dir = talloc_reference(c, parent->tst_dir);
    c->gen_dir = talloc_reference(c, parent->gen_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->libexec_dir = talloc_reference(c, parent->libexec_dir);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->shared_target = false;
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);
    c->testdeps = stringlist_new(c);
    c->testdir = talloc_asprintf(c, "%s/%s", c->tst_dir, called_path);
    c->autodeps = parent->autodeps;

    c->called_path = talloc_strdup(c, called_path);
    c->full_path = talloc_asprintf(c, "%s/%s", c->bin_dir, called_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_binary_destructor);

    return c;
}

int context_set_prefix(struct context *c, char *opt)
{
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    assert(c->prefix != NULL);
    /* FIXME: This cast is probably bad, is the talloc API broken? */
    talloc_unlink(c, (char *)c->prefix);
    c->prefix = talloc_reference(c, opt);

    if (c->prefix == NULL)
        return -1;

    return 0;
}

int context_set_testdir(struct context *c, char *opt)
{
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    assert(c->testdir != NULL);
    /* FIXME: This cast is probably bad, is the talloc API broken? */
    talloc_unlink(c, (char *)c->testdir);
    c->testdir = talloc_reference(c, opt);

    if (c->testdir == NULL)
        return -1;

    return 0;
}

int context_set_srcdir(struct context *c, char *opt)
{
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    assert(c->src_dir != NULL);
    /* FIXME: This cast is probably bad, is the talloc API broken? */
    talloc_unlink(c, (char *)c->src_dir);
    c->src_dir = talloc_reference(c, opt);

    if (c->src_dir == NULL)
        return -1;

    return 0;
}

int context_add_compileopt(struct context *c, const char *opt)
{
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    return stringlist_add(c->compile_opts, opt);
}

int context_add_linkopt(struct context *c, const char *opt)
{
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    return stringlist_add(c->link_opts, opt);
}

int context_add_library(struct context *c, const char *opt)
{
    int out;

    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    out = stringlist_add_ifnew(c->libraries, opt);
    if (out < 0)
        return out;

    if (lib_deps == NULL) {
        lib_deps_ctx = talloc_init("context_add_library(): lib_deps");
        atexit(&context_destructor);
        lib_deps = liblist_new(lib_deps_ctx);
    }

    liblist_add_to_sl_ifnew(lib_deps, opt, c->libraries);

    return 0;
}

int context_add_testdep(struct context *c, const char *opt)
{
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    return stringlist_add_ifnew(c->testdeps, opt);
}

int context_set_autodeps(struct context *c, bool opt)
{
    c->autodeps = opt;
    return 0;
}

void context_destructor(void)
{
    talloc_free(lib_deps_ctx);
}
