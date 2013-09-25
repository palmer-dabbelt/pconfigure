
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

#include "perl.h"
#include "../lambda.h"
#include <string.h>
#include <unistd.h>
#include <pinclude.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

static struct language *language_perl_search(struct language *l_uncast,
                                             struct language *parent,
                                             const char *path);
static const char *language_perl_objname(struct language *l_uncast,
                                         void *context, struct context *c);
static void language_perl_deps(struct language *l_uncast, struct context *c,
                               void (*func) (const char *, ...));
static void language_perl_build(struct language *l_uncast, struct context *c,
                                void (*func) (bool, const char *, ...));
static void language_perl_link(struct language *l_uncast, struct context *c,
                               void (*func) (bool, const char *, ...),
                               bool should_install);
static void language_perl_extras(struct language *l_uncast, struct context *c,
                                 void *context, void (*func) (const char *));

struct language *language_perl_new(struct clopts *o, const char *name)
{
    struct language_perl *l;

    if (strcmp(name, "perl") != 0)
        return NULL;

    l = talloc(o, struct language_perl);
    if (l == NULL)
        return NULL;

    language_init(&(l->l));
    l->l.name = talloc_strdup(l, "perl");
    l->l.compiled = false;
    l->l.compile_str = talloc_strdup(l, "");
    l->l.compile_cmd = talloc_strdup(l, "");
    l->l.link_str = talloc_strdup(l, "PERLC");
    l->l.link_cmd = talloc_strdup(l, "pperlc");
    l->l.search = &language_perl_search;
    l->l.objname = &language_perl_objname;
    l->l.deps = &language_perl_deps;
    l->l.build = &language_perl_build;
    l->l.link = &language_perl_link;
    l->l.extras = &language_perl_extras;

    return &(l->l);
}

struct language *language_perl_search(struct language *l_uncast,
                                      struct language *parent,
                                      const char *path)
{
    struct language_perl *l;

    l = talloc_get_type(l_uncast, struct language_perl);
    if (l == NULL)
        return NULL;

    if (strcmp(path + strlen(path) - 3, ".pl") != 0)
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->name, l_uncast->name) != 0)
        return NULL;

    return l_uncast;
}

const char *language_perl_objname(struct language *l_uncast, void *context,
                                  struct context *c)
{
    abort();
    return NULL;
}

void language_perl_deps(struct language *l_uncast, struct context *c,
                        void (*func) (const char *, ...))
{
    char *dirs[1];

    func("%s", c->full_path);

    dirs[0] = NULL;
    /* *INDENT-OFF* */
    pinclude_list(c->full_path, lambda(int, (const char *f, void *u),
                                       {
                                           func("%s", f);
                                           return 0;
                                       }
                      ), NULL, dirs);
    /* *INDENT-ON* */
}

void language_perl_build(struct language *l_uncast, struct context *c,
                         void (*func) (bool, const char *, ...))
{
    abort();
}

void language_perl_link(struct language *l_uncast, struct context *c,
                        void (*func) (bool, const char *, ...),
                        bool should_install)
{
    struct language_perl *l;
    void *context;
    const char *link_path;
    int obj_count;

    l = talloc_get_type(l_uncast, struct language_perl);
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

    /* FIXME: deps() doesn't get called because this isn't compiled
     * code so we need to fake this with extras() instead.  That means
     * every perl script gets set as an object to be linked and
     * therefor gets cat'd to the end of the file.  In this case we
     * want to skip those extra files and just link the first one. */
    obj_count = 0;
    stringlist_each(c->objects,
		    lambda(int, (const char *opt),
			   {
                               if (obj_count++ == 0)
                                   func(false, "\\ %s", opt);
			       return 0;
			   }
                    ));
    /* *INDENT-ON* */
    func(false, "\\ -o %s\n", link_path);

    TALLOC_FREE(context);
}

void language_perl_extras(struct language *l_uncast, struct context *c,
                          void *context, void (*func) (const char *))
{
    char *dirs[1];

    dirs[0] = NULL;
    /* *INDENT-OFF* */
    pinclude_list(c->full_path, lambda(int, (const char *f, void *u),
                                       {
                                           func(f);
                                           return 0;
                                       }
                      ), NULL, dirs);
    /* *INDENT-ON* */
}
