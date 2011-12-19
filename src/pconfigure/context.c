
/*
 * Copyright (C) 2011 Daniel Dabbelt
 *   <palmem@comcast.net>
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
#include <talloc.h>
#include <assert.h>
#include <string.h>

static int context_binary_destructor(struct context *c);
static int context_source_destructor(struct context *c);

struct context *context_new_defaults(struct clopts *o, void *context,
                                     struct makefile *mf,
                                     struct languagelist *ll)
{
    struct context *c;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_DEFAULTS;
    c->bin_dir = talloc_strdup(c, "bin");
    c->obj_dir = talloc_strdup(c, "obj");
    c->src_dir = talloc_strdup(c, "src");
    c->prefix = talloc_strdup(c, "/usr/local");
    c->compile_opts = stringlist_new(c);
    c->link_opts = stringlist_new(c);
    c->mf = talloc_reference(c, mf);
    c->ll = talloc_reference(c, ll);
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
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->language = NULL;

    c->full_path = talloc_asprintf(c, "%s/%s", c->bin_dir, called_path);

    talloc_set_destructor(c, &context_binary_destructor);

    return c;
}

int context_binary_destructor(struct context *c)
{
    assert(c->type == CONTEXT_TYPE_BINARY);
    fprintf(stderr, "context_binary_destructor('%s')\n", c->full_path);

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
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);
    c->mf = talloc_reference(c, parent->mf);
    c->ll = talloc_reference(c, parent->ll);
    c->language = NULL;

    c->full_path = talloc_asprintf(c, "%s/%s", c->src_dir, called_path);

    talloc_set_destructor(c, &context_source_destructor);

    return c;
}

int context_source_destructor(struct context *c)
{
    struct language *l;
    void *context;

    assert(c->type == CONTEXT_TYPE_SOURCE);
    fprintf(stderr, "context_source_destructor('%s', '%s')\n",
            c->full_path, c->parent->full_path);

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

    /* We need to allocate some temporary memory */
    context = talloc_new(NULL);

    /* Some languages don't need to be compiled (just linked) so we skip the
     * entire compiling phase. */
    if (language_needs_compile(l, c) == true)
    {
        const char *obj_name;

        /* This is the name that our code will be compiled into.  This must
         * succeed, as we just checked that it's necessary. */
        obj_name = language_objname(l, context, c);
        assert(obj_name != NULL);

        /* If we've already built this dependency, then it's not necessary to
         * add it to the build list. */
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
            language_cmds(l, c, lambda(void, (bool nam,
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
        }
    }

    /* Everything succeeded! */
    TALLOC_FREE(context);
    return 0;
}

int context_set_prefix(struct context *c, const char *opt)
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
