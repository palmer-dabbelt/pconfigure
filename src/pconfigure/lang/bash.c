
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

#include "bash.h"
#include "../lambda.h"
#include <talloc.h>
#include <string.h>
#include <clang-c/Index.h>
#include <unistd.h>

static struct language *language_bash_search(struct language *l_uncast,
                                             struct language *parent,
                                             const char *path);
static const char *language_bash_objname(struct language *l_uncast,
                                         void *context, struct context *c);
static void language_bash_deps(struct language *l_uncast, struct context *c,
                               void (*func) (const char *, ...));
static void language_bash_build(struct language *l_uncast, struct context *c,
                                void (*func) (bool, const char *, ...));
static void language_bash_link(struct language *l_uncast, struct context *c,
                               void (*func) (bool, const char *, ...));
static void language_bash_extras(struct language *l_uncast, struct context *c,
                                 void *context, void (*func) (const char *));

struct language *language_bash_new(struct clopts *o, const char *name)
{
    struct language_bash *l;

    if (strcmp(name, "bash") != 0)
        return NULL;

    l = talloc(o, struct language_bash);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "bash");
    l->l.compiled = false;
    l->l.compile_str = talloc_strdup(l, "");
    l->l.compile_cmd = talloc_strdup(l, "");
    l->l.link_str = talloc_strdup(l, "BASHC");
    l->l.link_cmd = talloc_strdup(l, "pbashc");
    l->l.search = &language_bash_search;
    l->l.objname = &language_bash_objname;
    l->l.deps = &language_bash_deps;
    l->l.build = &language_bash_build;
    l->l.link = &language_bash_link;
    l->l.extras = &language_bash_extras;

    return &(l->l);
}

struct language *language_bash_search(struct language *l_uncast,
                                      struct language *parent,
                                      const char *path)
{
    struct language_bash *l;

    l = talloc_get_type(l_uncast, struct language_bash);
    if (l == NULL)
        return NULL;

    if (strcmp(path + strlen(path) - 5, ".bash") != 0)
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->name, l_uncast->name) != 0)
        return NULL;

    return l_uncast;
}

const char *language_bash_objname(struct language *l_uncast, void *context,
                                  struct context *c)
{
    abort();
    return NULL;
}

void language_bash_deps(struct language *l_uncast, struct context *c,
                        void (*func) (const char *, ...))
{
    func("%s", c->full_path);
}

void language_bash_build(struct language *l_uncast, struct context *c,
                         void (*func) (bool, const char *, ...))
{
    abort();
}

void language_bash_link(struct language *l_uncast, struct context *c,
                        void (*func) (bool, const char *, ...))
{
    struct language_bash *l;
    void *context;

    l = talloc_get_type(l_uncast, struct language_bash);
    if (l == NULL)
        return;

    context = talloc_new(NULL);

    func(true, "echo -e \"%s\\t%s\"",
         l->l.link_str, c->full_path + strlen(c->bin_dir) + 1);

    func(false, "mkdir -p `dirname %s` >& /dev/null || true", c->full_path);

    func(false, "%s \\", l->l.link_cmd);
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
    func(false, "\\ -o %s\n", c->full_path);

    TALLOC_FREE(context);
}

void language_bash_extras(struct language *l_uncast, struct context *c,
                          void *context, void (*func) (const char *))
{
}
