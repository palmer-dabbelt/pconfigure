
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
#include <talloc.h>
#include <assert.h>
#include <string.h>

static int context_binary_destructor(struct context *c);
static int context_source_destructor(struct context *c);

struct context *context_new_defaults(struct clopts *o, void *context)
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

    return c;
}

struct context *context_new_binary(struct context *parent, void *context,
                                   const char *called_path)
{
    struct context *c;
    char *fullpath;
    int fullpath_size;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_BINARY;
    c->parent = c;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);

    fullpath_size = strlen(c->bin_dir) + strlen(called_path) + 3;
    fullpath = talloc_array(c, char, fullpath_size);
    fullpath[0] = '\0';
    strcat(fullpath, c->bin_dir);
    strcat(fullpath, "/");
    strcat(fullpath, called_path);
    c->full_path = fullpath;

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
    char *fullpath;
    int fullpath_size;

    c = talloc(context, struct context);
    c->type = CONTEXT_TYPE_SOURCE;
    c->parent = parent->parent;
    c->bin_dir = talloc_reference(c, parent->bin_dir);
    c->obj_dir = talloc_reference(c, parent->obj_dir);
    c->src_dir = talloc_reference(c, parent->src_dir);
    c->prefix = talloc_reference(c, parent->prefix);
    c->compile_opts = stringlist_copy(parent->compile_opts, c);
    c->link_opts = stringlist_copy(parent->link_opts, c);

    fullpath_size = strlen(c->bin_dir) + strlen(called_path) + 3;
    fullpath = talloc_array(c, char, fullpath_size);
    fullpath[0] = '\0';
    strcat(fullpath, c->bin_dir);
    strcat(fullpath, "/");
    strcat(fullpath, called_path);
    c->full_path = fullpath;

    talloc_set_destructor(c, &context_source_destructor);

    return c;
}

int context_source_destructor(struct context *c)
{
    assert(c->type == CONTEXT_TYPE_SOURCE);
    fprintf(stderr, "context_source_destructor('%s', '%s')\n",
            c->full_path, c->parent->full_path);

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
