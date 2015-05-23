
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

#include "c.h"
#include "funcs.h"
#include "str.h"
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

static struct language *language_c_search(struct language *l_uncast,
                                          struct language *parent,
                                          const char *path,
                                          struct context *c);
static const char *language_c_objname(struct language *l_uncast,
                                      void *context, struct context *c);
static void language_c_deps(struct language *l_uncast, struct context *c,
                            void (*func) (void *arg, const char *, ...),
                            void *arg);
static void language_c_build(struct language *l_uncast, struct context *c,
                             void (*func) (bool, const char *, ...));
static void language_c_link(struct language *l_uncast, struct context *c,
                            void (*func) (bool, const char *, ...),
                            bool should_install);
static void language_c_slib(struct language *l_uncast, struct context *c,
                            void (*func) (bool, const char *, ...));
static void language_c_extras(struct language *l_uncast, struct context *c,
                              void *context,
                              void (*func) (void *, const char *), void *arg);

static char *string_strip(const char *in, void *context);
static char *string_hashcode(const char *string, void *context);
static size_t count_char(const char *str, char c);

/* This converts from the clang inclusion format into the format
 * required by the pconfigure context support. */
struct pass_inclusions_args
{
    void (*func) (void *arg, const char *, ...);
    void *arg;
};
static void pass_inclusions(CXFile included_file,
                            CXSourceLocation * inclusion_stack,
                            unsigned include_len, void *args_uncast);

/* This is the function that searches for new sorts of C files that
 * are somehow related to all the existing files. */
struct find_files_args
{
    void *context;
    void (*func) (void *arg, const char *);
    void *arg;
    struct language_c *l;
};
static void find_files(void *args_uncast, const char *format, ...);

/* Here's a really nasty block of code: essentially the idea is that
 * if we haven't yet loaded C++ then we don't want to search for C++
 * files... */
bool have_loaded_cxx = false;

struct language_c *language_c_new_uc(struct clopts *o, const char *name)
{
    struct language_c *l;

    if (strcmp(name, "c") != 0)
        return NULL;

    l = talloc(o, struct language_c);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "c");
    l->l.link_name = talloc_strdup(l, "c");
    l->l.compile_str = talloc_strdup(l, "CC");
    l->l.compile_cmd = talloc_strdup(l, "${CC}");
    l->l.link_str = talloc_strdup(l, "LD");
    l->l.link_cmd = talloc_strdup(l, "${CC}");
#if defined(__APPLE__)
    l->l.so_ext = talloc_strdup(l, "dylib");
#elif defined(__linux__)
    l->l.so_ext = talloc_strdup(l, "so");
#else
#error "Set a shared object extension for your platform"
#endif
    l->l.so_ext_canon = talloc_strdup(l, "so");
    l->l.a_ext = talloc_strdup(l, "a");
    l->l.a_ext_canon = talloc_strdup(l, "a");
    l->l.compiled = true;
    l->l.cares_about_static = true;
    l->l.search = &language_c_search;
    l->l.objname = &language_c_objname;
    l->l.deps = &language_c_deps;
    l->l.build = &language_c_build;
    l->l.link = &language_c_link;
    l->l.slib = &language_c_slib;
    l->l.extras = &language_c_extras;
    l->cflags = talloc_strdup(l, "$(CFLAGS)");
    l->ldflags = talloc_strdup(l, "$(LDFLAGS)");

    return l;
}

struct language *language_c_search(struct language *l_uncast,
                                   struct language *parent,
                                   const char *path, struct context *c)
{
    struct language_c *l;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return NULL;

    if (strcmp(path + strlen(path) - 2, ".c") != 0
        && strcmp(path + strlen(path) - 3, ".ld") != 0)
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->link_name, l_uncast->link_name) != 0)
        return NULL;

    return l_uncast;
}

const char *language_c_objname(struct language *l_uncast, void *context,
                               struct context *c)
{
    char *o;
    const char *compileopts_hash, *langopts_hash, *compiler_hash,
        *prefix_hash;
    struct language_c *l;
    void *subcontext;
    const char *suffix;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return NULL;

    subcontext = talloc_new(NULL);
    compiler_hash = string_hashcode(l->l.compile_cmd, subcontext);
    prefix_hash = string_hashcode(c->prefix, subcontext);
    compileopts_hash = stringlist_hashcode(c->compile_opts, subcontext);
    langopts_hash = stringlist_hashcode(l->l.compile_opts, subcontext);

    /* This should be checked higher up in the stack, but just make sure */
    assert(c->full_path[strlen(c->src_dir)] == '/');

    /* Linker scripts have no dependencies. */
    if (strcmp(c->full_path + strlen(c->full_path) - 3, ".ld") == 0)
        suffix = "ld";
    else
        suffix = "o";

    o = talloc_asprintf(context, "%s/%s/%s-%s-%s-%s-%s.%s",
                        c->obj_dir, remove_dotdot(subcontext, c->full_path),
                        compiler_hash, compileopts_hash, langopts_hash,
                        prefix_hash,
                        c->shared_target ? "shared" : "static", suffix);

    TALLOC_FREE(subcontext);
    return o;
}

void language_c_deps(struct language *l_uncast, struct context *c,
                     void (*func) (void *arg, const char *, ...), void *arg)
{
    void *context;
    struct language_c *l;
    int clang_argc;
    char **clang_argv;
    int i;
    CXIndex index;
    CXTranslationUnit tu;

    /* Linker scripts have no dependencies. */
    if (strcmp(c->full_path + strlen(c->full_path) - 3, ".ld") == 0) {
        func(arg, "%s", c->full_path);
        return;
    }

    /* FIXME: This means tests have to be in a single source, which
     * isn't great. */
    if (c->parent->type == CONTEXT_TYPE_TEST) {
        func(arg, "%s", c->full_path);
        return;
    }

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return;

    context = talloc_new(NULL);

    /* Creates the argc/argv for a call to clang that will determine which
     * includes are used by the file in question. */
    {
        struct stringlist *lang_wo;
        struct stringlist *ctx_wo;

        lang_wo = stringlist_without(l->l.compile_opts, context, "-fopenmp");
        ctx_wo = stringlist_without(c->compile_opts, context, "-fopenmp");

        stringlist_add(ctx_wo, talloc_strdup(
                           l,
                           "-D__PCONFIGURE__IN_DEPENDENCY_RESOLUTION"
                           ));
        clang_argc = stringlist_size(lang_wo) + stringlist_size(ctx_wo) + 4;
        clang_argv = talloc_array(context, char *, clang_argc + 1);
        for (i = 0; i <= clang_argc; i++)
            clang_argv[i] = NULL;

        clang_argv[0] = talloc_strdup(clang_argv, c->full_path);
        clang_argv[1] = talloc_asprintf(clang_argv, "-I%s", c->hdr_dir);
        clang_argv[2] = talloc_asprintf(clang_argv, "-I%s", c->gen_dir);

        i = 3;
        i = stringlist_to_alloced_array(lang_wo, clang_argv, i);
        i = stringlist_to_alloced_array(ctx_wo, clang_argv, i);
        clang_argv[i] = NULL;
    }

    /* Asks libclang for the list of includes */
    index = clang_createIndex(0, 0);

    tu = clang_parseTranslationUnit(index, 0,
                                    (const char *const *)clang_argv,
                                    clang_argc, 0, 0, CXTranslationUnit_None);

    {
        struct pass_inclusions_args pai;

        pai.func = func;
        pai.arg = arg;
        clang_getInclusions(tu, &pass_inclusions, &pai);
    }

    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);

    TALLOC_FREE(context);
}

void language_c_build(struct language *l_uncast, struct context *c,
                      void (*func) (bool, const char *, ...))
{
    struct language_c *l;
    void *context;
    const char *obj_path;
    const char *compile_str;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return;

    context = talloc_new(NULL);
    obj_path = language_objname(l_uncast, context, c);

    /* Linker scripts have a different compile string. */
    if (strcmp(c->full_path + strlen(c->full_path) - 3, ".ld") == 0)
        compile_str = "LDS";
    else
        compile_str = l->l.compile_str;

    func(true, "echo -e \"%s\\t%s\"",
         compile_str, c->full_path + strlen(c->src_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", obj_path);

    /* Linker scripts don't really need to be compiled, at least for now. */
    if (strcmp(c->full_path + strlen(c->full_path) - 3, ".ld") == 0) {
        func(false, "cp %s %s", c->full_path, obj_path);
        TALLOC_FREE(context);
        return;
    }

    func(false, "%s %s\\", l->l.compile_cmd, l->cflags);

    if (c->shared_target == true)
        func(false, "\\ -fPIC");

    func_stringlist_each_cmd_cont(l->l.compile_opts, func);
    func_stringlist_each_cmd_cont(c->compile_opts, func);

    func(false, "\\ -I%s", c->hdr_dir);
    func(false, "\\ -I%s", c->gen_dir);
    func(false, "\\ -D__PCONFIGURE__PREFIX=\\\"%s\\\"", c->prefix);
    func(false, "\\ -D__PCONFIGURE__LIBEXEC=\\\"%s/%s\\\"",
         c->prefix, c->libexec_dir);
    func(false, "\\ -c %s -o %s\n", c->full_path, obj_path);

    TALLOC_FREE(context);
}

void language_c_link(struct language *l_uncast, struct context *c,
                     void (*func) (bool, const char *, ...),
                     bool should_install)
{
    struct language_c *l;
    void *context;
    const char *link_path;

    l = talloc_get_type(l_uncast, struct language_c);
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

#ifdef __APPLE__
    /* Apple's linker throws a warning whenever LIBDIR doesn't exist,
     * so I just make it here.  This isn't necessary anywhere else
     * because other compilers don't throw this warning. */
    func(false, "mkdir -p %s >& /dev/null || true", c->lib_dir);
#endif

    func(false, "\\\t@%s %s", l->l.link_cmd, l->ldflags);
    func(false, "\\ -L%s", c->lib_dir);
    if (should_install == false) {
#ifdef __APPLE__
        func(false, "\\ -Wl,-rpath,`pwd`/%s", c->lib_dir);
#else
        if (c->parent->type != CONTEXT_TYPE_TEST) {
            switch (count_char(c->full_path, '/')) {
            case 1:
                func(false, "\\ -Wl,-rpath,\\$$ORIGIN/../%s", c->lib_dir);
                break;
            case 2:
                func(false, "\\ -Wl,-rpath,\\$$ORIGIN/../../%s", c->lib_dir);
                break;
            case 3:
                func(false, "\\ -Wl,-rpath,\\$$ORIGIN/../../../%s", c->lib_dir);
                break;
            default:
                fprintf(stderr, "Too many /'s in bindir\n");
                abort();
                break;
            }
        } else {
            func(false, "\\ -Wl,-rpath,%s", c->lib_dir);
        }
#endif
    } else {
        func(false, "\\ -Wl,-rpath,%s/%s", c->prefix, c->lib_dir);
    }

    if (c->shared_target == true)
        func(false, "\\ -fPIC");

    func_stringlist_each_cmd_Tcont(c->objects, func);

    func_stringlist_each_cmd_lcont(c->libraries, func);

    func_stringlist_each_cmd_cont(l->l.link_opts, func);
    func_stringlist_each_cmd_cont(c->link_opts, func);

    func(false, "\\ -o %s\n", link_path);

    TALLOC_FREE(context);
}

void language_c_slib(struct language *l_uncast, struct context *c,
                     void (*func) (bool, const char *, ...))
{
    struct language_c *l;
    void *context;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return;

    context = talloc_new(NULL);

    func(true, "echo -e \"%s\\t%s\"",
         l->l.link_str, c->full_path + strlen(c->lib_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", c->link_path);

    if (c->shared_target == true)
        func(false, "\\\t@%s -shared %s", l->l.link_cmd, l->ldflags);
    else
        func(false, "\\\t@${AR} rcs %s", c->link_path);

#ifdef __APPLE__
    if (c->shared_target == true)
        func(false, "\\ -undefined dynamic_lookup");
#endif

    if (c->shared_target == true) {
        func_stringlist_each_cmd_cont(l->l.link_opts, func);
        func_stringlist_each_cmd_cont(c->link_opts, func);
    }

    func_stringlist_each_cmd_cont(c->objects, func);

    if (c->shared_target == true)
        func(false, "\\ -o %s", c->link_path);

#ifdef __linux__
    /* Automatically name all shared libraries -- this is probably
     * best practice. */
    if (c->shared_target == true)
        func(false, "\\ -Wl,-soname,%s\n", c->called_path);
#endif

#ifdef __APPLE__
    /* In order for OSX to recognize shared libraries we need this
     * special bit of magic -- it's the analog of -soname in Linux. */
    if (c->shared_target == true) {
        func(false, "\\ -Wl,-install_name,@rpath/%s\n",
             c->full_path + strlen(c->lib_dir) + 1);
    }
#endif

    TALLOC_FREE(context);
}

void language_c_extras(struct language *l_uncast, struct context *c,
                       void *context,
                       void (*func) (void *arg, const char *), void *arg)
{
    struct find_files_args ffa;

    ffa.context = context;
    ffa.func = func;
    ffa.arg = arg;
    ffa.l = talloc_get_type(l_uncast, struct language_c);

    language_deps(l_uncast, c, &find_files, &ffa);
}

char *string_strip(const char *filename_cstr, void *context)
{
    char *source_name;

    source_name = talloc_strdup(context, filename_cstr);

    {
        int last_dir, pprev_dir, prev_dir, o;
        size_t i;

        pprev_dir = -1;
        prev_dir = -1;
        last_dir = -1;
        i = 0;
        o = 0;
        while (i < strlen(filename_cstr)) {
            source_name[o] = filename_cstr[i];

            if ((o > 0) && (filename_cstr[i] == '/')) {
                pprev_dir = prev_dir;
                prev_dir = last_dir;
                last_dir = o;
            }

            if (i > 2) {
                if (filename_cstr[i - 1] == '.'
                    && filename_cstr[i - 2] == '.') {
                    if (pprev_dir > 0) {
                        o = pprev_dir;
                        pprev_dir = -1;
                        prev_dir = -1;
                        last_dir = -1;
                    }
                }
            }

            source_name[o] = filename_cstr[i];

            i++;
            o++;
        }
        source_name[o] = '\0';
    }

    return source_name;
}

char *string_hashcode(const char *string, void *context)
{
    unsigned int hash;
    char c;

    hash = 5381;

    /* FIXME: http://www.cse.yorku.ca/~oz/hash.html */
    while ((c = *string++) != '\0')
        hash = hash * 33 ^ c;
    hash = hash * 33 ^ ' ';

    return talloc_asprintf(context, "%u", hash);
}

void pass_inclusions(CXFile included_file,
                     CXSourceLocation * inclusion_stack,
                     unsigned include_len, void *args_uncast)
{
    struct pass_inclusions_args *args;
    CXString fn;
    const char *fn_cstr;
    void *context;

    context = talloc_new(NULL);

    args = args_uncast;

    fn = clang_getFileName(included_file);

    fn_cstr = clang_getCString(fn);
    args->func(args->arg, "%s", string_strip(fn_cstr, context));
    clang_disposeString(fn);

    TALLOC_FREE(context);
}

void find_files(void *args_uncast, const char *format, ...)
{
    va_list args;
    char *cfile;
    char *sfile;
    char *hfile;
    char *cxxfile;

    void *context;
    void (*func) (void *arg, const char *);
    void *arg;

    {
        struct find_files_args *args;
        args = args_uncast;

        context = talloc_new(args->context);
        func = args->func;
        arg = args->arg;
    }

    va_start(args, format);
    hfile = talloc_vasprintf(context, format, args);
    va_end(args);

    va_start(args, format);
    cfile = talloc_vasprintf(context, format, args);
    va_end(args);

    if (cfile[0] == '/') {
        TALLOC_FREE(context);
        return;
    }

    cfile[strlen(cfile) - 1] = 'c';

    va_start(args, format);
    sfile = talloc_vasprintf(context, format, args);
    va_end(args);
    sfile[strlen(sfile) - 1] = 'S';

    if (strcmp(cfile, hfile) != 0)
        if (access(cfile, R_OK) == 0)
            func(arg, cfile);

    if (strcmp(sfile, hfile) != 0)
        if (access(sfile, R_OK) == 0)
            func(arg, sfile);

    if (have_loaded_cxx) {
        va_start(args, format);
        cxxfile = talloc_array(context, char, strlen(cfile) + 20);
        va_end(args);

        memset(cxxfile, 0, strlen(cfile) + 10);
        strncpy(cxxfile, cfile, strlen(cfile) - 2);
        strcat(cxxfile, ".c++");
        if (strcmp(cxxfile, hfile) != 0)
            if (access(cxxfile, R_OK) == 0)
                func(arg, cxxfile);

        memset(cxxfile, 0, strlen(cfile) + 10);
        strncpy(cxxfile, cfile, strlen(cfile) - 2);
        strcat(cxxfile, ".cxx");
        if (strcmp(cxxfile, hfile) != 0)
            if (access(cxxfile, R_OK) == 0)
                func(arg, cxxfile);

        memset(cxxfile, 0, strlen(cfile) + 10);
        strncpy(cxxfile, cfile, strlen(cfile) - 2);
        strcat(cxxfile, ".cpp");
        if (strcmp(cxxfile, hfile) != 0)
            if (access(cxxfile, R_OK) == 0)
                func(arg, cxxfile);
    }

    TALLOC_FREE(context);
}

size_t count_char(const char *str, char c)
{
    size_t count;

    count = 0;
    while (*str != '\0') {
        if (*str == c)
            count++;
        str++;
    }
    return count;
}
