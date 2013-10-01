
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
#include "../lambda.h"
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
                                          const char *path);
static const char *language_c_objname(struct language *l_uncast,
                                      void *context, struct context *c);
static void language_c_deps(struct language *l_uncast, struct context *c,
                            void (*func) (const char *, ...));
static void language_c_build(struct language *l_uncast, struct context *c,
                             void (*func) (bool, const char *, ...));
static void language_c_link(struct language *l_uncast, struct context *c,
                            void (*func) (bool, const char *, ...),
                            bool should_install);
static void language_c_slib(struct language *l_uncast, struct context *c,
                            void (*func) (bool, const char *, ...));
static void language_c_extras(struct language *l_uncast, struct context *c,
                              void *context, void (*func) (const char *));

static char *string_strip(const char *in, void *context);
static bool str_ends(const char *haystack, const char *needle);
static char *string_hashcode(const char *string, void *context);

struct language *language_c_new(struct clopts *o, const char *name)
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
    l->l.so_ext = talloc_strdup(l, "so");
    l->l.compiled = true;
    l->l.search = &language_c_search;
    l->l.objname = &language_c_objname;
    l->l.deps = &language_c_deps;
    l->l.build = &language_c_build;
    l->l.link = &language_c_link;
    l->l.slib = &language_c_slib;
    l->l.extras = &language_c_extras;

    return &(l->l);
}

struct language *language_c_search(struct language *l_uncast,
                                   struct language *parent, const char *path)
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
    const char *compileopts_hash, *langopts_hash, *compiler_hash;
    struct language_c *l;
    void *subcontext;
    const char *suffix;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return NULL;

    subcontext = talloc_new(NULL);
    compiler_hash = string_hashcode(l->l.compile_cmd, subcontext);
    compileopts_hash = stringlist_hashcode(c->compile_opts, subcontext);
    langopts_hash = stringlist_hashcode(l->l.compile_opts, subcontext);

    /* This should be checked higher up in the stack, but just make sure */
    assert(c->full_path[strlen(c->src_dir)] == '/');

    /* Linker scripts have no dependencies. */
    if (strcmp(c->full_path + strlen(c->full_path) - 3, ".ld") == 0)
        suffix = "ld";
    else
        suffix = "o";

    o = talloc_asprintf(context, "%s/%s/%s-%s-%s-%s.%s",
                        c->obj_dir, c->full_path,
                        compiler_hash, compileopts_hash, langopts_hash,
                        c->shared_target ? "shared" : "static", suffix);

    TALLOC_FREE(subcontext);
    return o;
}

void language_c_deps(struct language *l_uncast, struct context *c,
                     void (*func) (const char *, ...))
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
        func(c->full_path);
        return;
    }

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return;

    context = talloc_new(NULL);

    /* Creates the argc/argv for a call to clang that will determine which
     * includes are used by the file in question. */
    clang_argc = stringlist_size(l->l.compile_opts)
        + stringlist_size(c->compile_opts) + 3;
    clang_argv = talloc_array(context, char *, clang_argc + 1);
    for (i = 0; i <= clang_argc; i++)
        clang_argv[i] = NULL;

    clang_argv[0] = talloc_strdup(clang_argv, c->full_path);
    clang_argv[1] = talloc_asprintf(clang_argv, "-I%s", c->hdr_dir);
    clang_argv[2] = talloc_asprintf(clang_argv, "-I%s", c->gen_dir);
    i = 3;
    /* *INDENT-OFF* */
    stringlist_each(l->l.compile_opts,
		    lambda(int, (const char *str),
			   {
			       if (strcmp(str, "-fopenmp") == 0) {
				   clang_argc--;
				   return 0;
			       }

			       clang_argv[i] = talloc_strdup(clang_argv, str);
			       i++;
			       return 0;
			   }
                    ));
    stringlist_each(c->compile_opts,
		    lambda(int, (const char *str),
			   {
			       if (strcmp(str, "-fopenmp") == 0) {
				   clang_argc--;
				   return 0;
			       }

			       clang_argv[i] = talloc_strdup(clang_argv, str);
			       i++;
			       return 0;
			   }
                    ));
    /* *INDENT-ON* */

    /* Asks libclang for the list of includes */
    index = clang_createIndex(0, 0);
    /* *INDENT-OFF* */
    tu = clang_parseTranslationUnit(index, 0,
                                    (const char *const *)clang_argv,
                                    clang_argc, 0, 0,
                                    CXTranslationUnit_None);
    clang_getInclusions(tu,
			lambda(void,
			       (CXFile included_file,
				CXSourceLocation * inclusion_stack,
				unsigned include_len, void *unused),
			       {
                                   CXString fn;
                                   const char *fn_cstr;
                                   fn = clang_getFileName(included_file);
                                   fn_cstr = clang_getCString(fn);

				   func("%s", string_strip(fn_cstr, context));
                                   clang_disposeString(fn);
			       }
			    ), NULL);
    /* *INDENT-ON* */
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

    func(false, "%s\\", l->l.compile_cmd);

    if (c->shared_target == true)
        func(false, "\\ -fPIC");

    /* *INDENT-OFF* */
    stringlist_each(l->l.compile_opts,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
                    ));
    stringlist_each(c->compile_opts,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
                    ));
    /* *INDENT-ON* */
    func(false, "\\ -I%s", c->hdr_dir);
    func(false, "\\ -I%s", c->gen_dir);
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

    func(false, "\\\t@%s ", l->l.link_cmd);
    func(false, "\\ -L%s", c->lib_dir);
    if (should_install == false)
        func(false, "\\ -Wl,-rpath,\\$$ORIGIN/../%s", c->lib_dir);
    else
        func(false, "\\ -Wl,-rpath,%s/%s", c->prefix, c->lib_dir);

    if (c->shared_target == true)
        func(false, "\\ -fPIC");

    /* *INDENT-OFF* */
    stringlist_each(c->objects,
		    lambda(int, (const char *opt),
			   {
			       if (str_ends(opt, ".ld"))
				   func(false, "\\ -T%s", opt);
			       else
				   func(false, "\\ %s", opt);

			       return 0;
			   }
			));
    stringlist_each(c->libraries,
		    lambda(int, (const char *lib),
			   {
			       func(false, "\\ -l%s", lib);
			       return 0;
			   }
			));
    stringlist_each(l->l.link_opts,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
			));
    stringlist_each(c->link_opts,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
			));
    /* *INDENT-ON* */
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
         l->l.link_str, c->full_path + strlen(c->bin_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", c->link_path);

    func(false, "\\\t@%s -shared", l->l.link_cmd);
    /* *INDENT-OFF* */
    stringlist_each(l->l.link_opts,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
                    ));
    stringlist_each(c->link_opts,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
                    ));
    stringlist_each(c->objects,
		    lambda(int, (const char *opt),
			   {
			       func(false, "\\ %s", opt);
			       return 0;
			   }
                    ));
    /* *INDENT-ON* */
    func(false, "\\ -o %s\n", c->link_path);

    TALLOC_FREE(context);
}

void language_c_extras(struct language *l_uncast, struct context *c,
                       void *context, void (*func) (const char *))
{
    /* *INDENT-OFF* */
    language_deps(l_uncast, c, 
		  lambda(void, (const char *format, ...),
			 {
			     va_list args;
			     char *cfile;
			     char *sfile;
			     char *hfile;
			     char *cxxfile;

			     va_start(args, format);
			     hfile = talloc_vasprintf(context, format, args);
			     va_end(args);

			     va_start(args, format);
			     cfile = talloc_vasprintf(context, format, args);
			     va_end(args);

			     cfile[strlen(cfile)-1] = 'c';

			     va_start(args, format);
			     sfile = talloc_vasprintf(context, format, args);
			     va_end(args);
			     sfile[strlen(sfile)-1] = 'S';

			     if (strcmp(cfile, hfile) != 0)
				 if (access(cfile, R_OK) == 0)
				     func(cfile);

			     if (strcmp(sfile, hfile) != 0)
				 if (access(sfile, R_OK) == 0)
				     func(sfile);
			     
			     va_start(args, format);
			     cxxfile = talloc_array(context, char,
                                                    strlen(cfile) + 20);
			     va_end(args);

			     memset(cxxfile, 0, strlen(cfile) + 10);
			     strncpy(cxxfile, cfile, strlen(cfile) - 2);
			     strcat(cxxfile, ".c++");
			     if (access(cxxfile, R_OK) == 0)
				 func(cxxfile);

			     memset(cxxfile, 0, strlen(cfile) + 10);
			     strncpy(cxxfile, cfile, strlen(cfile) - 2);
			     strcat(cxxfile, ".cxx");
			     if (access(cxxfile, R_OK) == 0)
				 func(cxxfile);

			     memset(cxxfile, 0, strlen(cfile) + 10);
			     strncpy(cxxfile, cfile, strlen(cfile) - 2);
			     strcat(cxxfile, ".cpp");
			     if (access(cxxfile, R_OK) == 0)
				 func(cxxfile);

			     talloc_unlink(context, cfile);
			     talloc_unlink(context, hfile);
			     talloc_unlink(context, cxxfile);
			 }
		      ));
    /* *INDENT-ON* */
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

            if (filename_cstr[i - 1] == '.' && filename_cstr[i - 2] == '.') {
                if (pprev_dir > 0) {
                    o = pprev_dir;
                    pprev_dir = -1;
                    prev_dir = -1;
                    last_dir = -1;
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

bool str_ends(const char *haystack, const char *needle)
{
    if (strlen(haystack) < strlen(needle))
        return false;

    return strcmp(haystack + strlen(haystack) - strlen(needle), needle) == 0;
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
