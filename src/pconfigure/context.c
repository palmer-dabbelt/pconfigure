
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
#include "lambda.h"
#include <assert.h>
#include <string.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

static int context_binary_destructor(struct context *c);
static int context_library_destructor(struct context *c);
static int context_header_destructor(struct context *c);
static int context_source_destructor(struct context *c);

struct context *context_new_defaults(struct clopts *o, void *context,
                                     struct makefile *mf,
                                     struct languagelist *ll,
                                     struct contextstack *s)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_DEFAULTS;
    c->bin_dir = talloc_strdup(c, "bin");
    c->lib_dir = talloc_strdup(c, "lib");
    c->hdr_dir = talloc_asprintf(c, "%sinclude", o->source_path);
    c->obj_dir = talloc_strdup(c, "obj");
    c->src_dir = talloc_asprintf(c, "%ssrc", o->source_path);
    c->prefix = talloc_strdup(c, "/usr/local");
    c->compile_opts = stringlist_new(c);
    c->link_opts = stringlist_new(c);
    c->mf = talloc_reference(c, mf);
    c->ll = talloc_reference(c, ll);
    c->s = s;
    c->language = NULL;

    return c;
}

struct context *context_new_binary(struct context *parent, void *context,
                                   const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_BINARY;
    c->parent = c;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);

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

    /* *INDENT-OFF* */
#ifdef DEBUG
    stringlist_each(c->objects,
		    lambda(int, (const char *obj),
			   {
			       fprintf(stderr, "obj: %s\n", obj);
			       return 0;
			   }
			));
#endif
    /* *INDENT-ON* */

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
    /* *INDENT-OFF* */
    stringlist_each(c->objects, lambda(int, (const char *obj),
			       {
				   makefile_add_dep(c->mf, "%s", obj);
				   return 0;
			       }
		      ));
    stringlist_each(c->libraries, lambda(int, (const char *lib),
			       {
				   makefile_add_dep(c->mf, "%s/lib%s.so",
						    c->lib_dir, lib);
				   return 0;
			       }
		      ));
    /* *INDENT-ON* */
    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    /* *INDENT-OFF* */
    language_link(l, c, lambda(void, (bool nam,
				      const char *format, ...),
			       {
				   va_list args;
				   va_start(args, NULL);
				   if (nam == true)
				       makefile_vnam_cmd(c->mf, format, args);
				   else
				       makefile_vadd_cmd(c->mf, format, args);
				   va_end(args);
			       }
		      ), false);
    /* *INDENT-ON* */
    makefile_end_cmds(c->mf);

    /* Link a second time, but with the install path now */
    makefile_create_target(c->mf, c->link_path_install);

    makefile_start_deps(c->mf);
    /* *INDENT-OFF* */
    stringlist_each(c->objects, lambda(int, (const char *obj),
			       {
				   makefile_add_dep(c->mf, "%s", obj);
				   return 0;
			       }
		      ));
    stringlist_each(c->libraries, lambda(int, (const char *lib),
			       {
				   makefile_add_dep(c->mf, "%s/lib%s.so",
						    c->lib_dir, lib);
				   return 0;
			       }
		      ));
    /* *INDENT-ON* */
    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    /* *INDENT-OFF* */
    language_link(l, c, lambda(void, (bool nam,
				      const char *format, ...),
			       {
				   va_list args;
				   va_start(args, NULL);
				   if (nam == true)
				       makefile_vnam_cmd(c->mf, format, args);
				   else
				       makefile_vadd_cmd(c->mf, format, args);
				   va_end(args);
			       }
		      ), true);
    /* *INDENT-ON* */
    makefile_end_cmds(c->mf);

    /* There is an install/uninstall target */
    tmp = talloc_asprintf(context, "echo -e \"INS\\t%s\"", c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp = talloc_asprintf(context,
                          "mkdir -p `dirname \"%s/%s\"` >& /dev/null || true",
                          c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp =
        talloc_asprintf(context,
                        "install -m a=rx -D %s $D/`dirname \"%s/%s\"`",
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
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);

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

    assert(c->type == CONTEXT_TYPE_LIBRARY);
#ifdef DEBUG
    fprintf(stderr, "context_library_destructor('%s')\n", c->full_path);
#endif

    l = c->language;
    assert(l != NULL);

    context = talloc_new(NULL);

    /* *INDENT-OFF* */
#ifdef DEBUG
    stringlist_each(c->objects,
		    lambda(int, (const char *obj),
			   {
			       fprintf(stderr, "obj: %s\n", obj);
			       return 0;
			   }
			));
#endif
    /* *INDENT-ON* */

    hash_langlinkopts = stringlist_hashcode(c->language->link_opts, context);
    hash_linkopts = stringlist_hashcode(c->link_opts, context);
    hash_objs = stringlist_hashcode(c->objects, context);
    talloc_unlink(c, (char *)c->link_path);
    c->link_path = talloc_asprintf(c, "%s/%s/%s-%s-%s.shlib",
                                   c->obj_dir, c->full_path,
                                   hash_langlinkopts, hash_linkopts,
                                   hash_objs);

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
    /* *INDENT-OFF* */
    stringlist_each(c->objects, lambda(int, (const char *obj),
			       {
				   makefile_add_dep(c->mf, "%s", obj);
				   return 0;
			       }
		      ));
    /* *INDENT-ON* */
    makefile_end_deps(c->mf);

    makefile_start_cmds(c->mf);
    /* *INDENT-OFF* */
    language_slib(l, c, lambda(void, (bool nam,
				      const char *format, ...),
			       {
				   va_list args;
				   va_start(args, NULL);
				   if (nam == true)
				       makefile_vnam_cmd(c->mf, format, args);
				   else
				       makefile_vadd_cmd(c->mf, format, args);
				   va_end(args);
			       }
		      ));
    /* *INDENT-ON* */
    makefile_end_cmds(c->mf);

    /* There is an install/uninstall target */
    tmp = talloc_asprintf(context, "echo -e \"INS\\t%s\"", c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp = talloc_asprintf(context,
                          "mkdir -p `dirname \"%s/%s\"` >& /dev/null || true",
                          c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp =
        talloc_asprintf(context,
                        "install -m a=r -D %s $D/`dirname \"%s/%s\"`",
                        c->full_path, c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);

    tmp = talloc_asprintf(context, "%s/%s", c->prefix, c->full_path);
    makefile_add_uninstall(c->mf, tmp);

    makefile_add_distclean(c->mf, c->lib_dir);

    TALLOC_FREE(context);
    return 0;
}

struct context *context_new_header(struct context *parent, void *context,
                                   const char *called_path)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_LIBRARY;
    c->parent = c;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);

    c->full_path = talloc_asprintf(c, "%s/%s", c->hdr_dir, called_path);
    c->link_path = talloc_strdup(c, "");
    c->link_path_install = talloc_strdup(c, "");

    talloc_set_destructor(c, &context_header_destructor);

    return c;
}

int context_header_destructor(struct context *c)
{
    char *tmp;
    void *context;

    context = talloc_new(c);

    /* There is an install/uninstall target */
    tmp = talloc_asprintf(context, "echo -e \"INS\\t%s\"", c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp = talloc_asprintf(context,
                          "mkdir -p `dirname \"%s/%s\"` >& /dev/null || true",
                          c->prefix, c->full_path);
    makefile_add_install(c->mf, tmp);
    tmp =
        talloc_asprintf(context,
                        "install -m a=r -D %s $D/`dirname \"%s/%s\"`",
                        c->full_path, c->prefix, c->full_path);
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
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);

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
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->lib_dir = talloc_reference(c, parent->lib_dir);
    c->hdr_dir = talloc_reference(c, parent->hdr_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->s = parent->s;
    c->language = NULL;
    c->objects = stringlist_new(c);
    c->libraries = stringlist_new(c);

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
    l = languagelist_search(c->ll, c->parent->language, c->full_path);
    if (l == NULL)
    {
        fprintf(stderr, "No language found for '%s'\n", c->full_path);

        if ((c->parent == NULL) || (c->parent->language == NULL))
            abort();

        fprintf(stderr, "Parent language is '%s', from '%s'\n",
                c->parent->language->name, c->parent->full_path);
        abort();
    }
    c->parent->language = l;

    /* We need to allocate some temporary memory */
    context = talloc_new(NULL);

    /* Some languages don't need to be compiled (just linked) so we skip the
     * entire compiling phase. */
    if (language_needs_compile(l, c) == true)
    {
        /* This is the name that our code will be compiled into.  This must
         * succeed, as we just checked that it's necessary. */
        obj_name = language_objname(l, context, c);
        assert(obj_name != NULL);

        /* If we've already built this dependency, then it's not necessary to
         * add it to the build list again, so skip it. */
        if (!stringlist_include(c->mf->targets, obj_name))
        {
            makefile_add_targets(c->mf, obj_name);
            makefile_create_target(c->mf, obj_name);

	    /* *INDENT-OFF* */
            makefile_start_deps(c->mf);
            language_deps(l, c, lambda(void, (const char *format, ...),
                                       {
					   va_list args;
					   va_start(args, NULL);
					   makefile_vadd_dep(c->mf,
							     format, args);
					   va_end(args);
                                       }
			      ));
            makefile_end_deps(c->mf);
	    /* *INDENT-ON* */

	    /* *INDENT-OFF* */
            makefile_start_cmds(c->mf);
            language_build(l, c, lambda(void, (bool nam,
					       const char *format, ...),
					{
					    va_list args;
					    va_start(args, NULL);
					    if (nam == true)
						makefile_vnam_cmd(c->mf, format,
								 args);
					    else
						makefile_vadd_cmd(c->mf, format,
								  args);
					    va_end(args);
					}
                          ));
            makefile_end_cmds(c->mf);
	    /* *INDENT-ON* */

            makefile_add_targets(c->mf, obj_name);
            makefile_add_clean(c->mf, obj_name);
            makefile_add_cleancache(c->mf, c->obj_dir);
        }
    }
    else
    {
        /* The "objects" for languages that aren't compiled are really just the
         * included sources. */
        obj_name = talloc_reference(context, c->full_path);
    }

    /* Adds every "extra" (which is defined as any other sources that should be 
     * linked in as a result of this SOURCES += line) to the stack. */
    if (stringlist_include(c->parent->objects, obj_name) == false)
    {
	/* *INDENT-OFF* */
	language_extras(l, c, context,
			lambda(void, (const char * extra),
			       {
				   contextstack_push_fullsrc(c->s, extra);
			       }
			    ));
	/* *INDENT-ON* */

        stringlist_add(c->parent->objects, obj_name);
    }

    /* Run some language-specific quirks here */
    language_quirks(l, c, c->mf);

    /* Everything succeeded! */
    TALLOC_FREE(context);
    return 0;
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
    if (c == NULL)
        return -1;
    if (opt == NULL)
        return -1;

    return stringlist_add(c->libraries, opt);
}
