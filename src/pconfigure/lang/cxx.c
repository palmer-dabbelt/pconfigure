
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

#include "cxx.h"
#include <string.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

/* Instance methods. */
static struct language *language_cxx_search(struct language *l_uncast,
                                            struct language *parent,
                                            const char *path,
                                            struct context *c);
static void language_cxx_extras(struct language *l_uncast, struct context *c,
                                void *context,
                                void (*func) (void *arg, const char *),
                                void *);

/* Searches for C++-looking files that are close to the current
 * file. */
struct find_similar_files_args
{
    struct context *c;
    void *context;
    void *arg;
    void (*func) (void *, const char *);
};
static void find_similar_files(void *arg_uncast, const char *format, ...);

struct language *language_cxx_new(struct clopts *o, const char *name)
{
    struct language_c *l;

    if (strcmp(name, "c++") != 0)
        return NULL;

    l = language_c_new_uc(o, "c");
    if (l == NULL)
        return NULL;

    l->l.name = talloc_strdup(l, "c++");
    l->l.compiled = true;
    l->l.compile_str = talloc_strdup(l, "C++");
    l->l.compile_cmd = talloc_strdup(l, "${CXX}");
    l->l.link_str = talloc_strdup(l, "LD++");
    l->l.link_cmd = talloc_strdup(l, "${CXX}");
    l->l.search = &language_cxx_search;
    l->l.extras = &language_cxx_extras;
    l->cflags = talloc_strdup(l, "$(CXXFLAGS)");

    return &(l->l);
}

struct language *language_cxx_search(struct language *l_uncast,
                                     struct language *parent,
                                     const char *path, struct context *c)
{
    struct language_c *l;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return NULL;

    if ((strcmp(path + strlen(path) - 4, ".c++") != 0) &&
        (strcmp(path + strlen(path) - 4, ".cxx") != 0) &&
        (strcmp(path + strlen(path) - 4, ".cpp") != 0) &&
        (strcmp(path + strlen(path) - 3, ".cc") != 0))
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->link_name, l_uncast->link_name) != 0)
        return NULL;

    return l_uncast;
}

void language_cxx_extras(struct language *l_uncast, struct context *c,
                         void *context,
                         void (*func) (void *, const char *), void *arg)
{
    struct find_similar_files_args args;

    args.c = c;
    args.context = context;
    args.func = func;
    args.arg = arg;

    language_deps(l_uncast, c, &find_similar_files, &args);
}

void find_similar_files(void *args_uncast, const char *format, ...)
{
    va_list args;
    char *cfile;
    char *cxxfile;

    void *context;
    void (*func) (void *, const char *);
    void *arg;

    {
        struct find_similar_files_args *args;
        args = args_uncast;
        context = talloc_new(args->context);
        func = args->func;
        arg = args->arg;
    }

    va_start(args, format);

    cfile = talloc_vasprintf(context, format, args);

    if (cfile[0] == '/') {
        TALLOC_FREE(context);
        return;
    }

    cxxfile = talloc_array(context, char, strlen(cfile) + 20);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 2);
    strcat(cxxfile, ".c++");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 2);
    strcat(cxxfile, ".cxx");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 2);
    strcat(cxxfile, ".cpp");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 2);
    strcat(cxxfile, ".cc");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 3);
    strcat(cxxfile, ".c++");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 3);
    strcat(cxxfile, ".cxx");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 3);
    strcat(cxxfile, ".cpp");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 3);
    strcat(cxxfile, ".cc");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 4);
    strcat(cxxfile, ".c++");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 4);
    strcat(cxxfile, ".cxx");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 4);
    strcat(cxxfile, ".cpp");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    memset(cxxfile, 0, strlen(cfile) + 10);
    strncpy(cxxfile, cfile, strlen(cfile) - 4);
    strcat(cxxfile, ".cc");
    if (access(cxxfile, R_OK) == 0)
        func(arg, cxxfile);

    if (strcmp(cfile + strlen(cfile) - 2, ".h") == 0)
        cfile[strlen(cfile) - 1] = 'c';
    if (strcmp(cfile + strlen(cfile) - 4, ".h++") == 0)
        cfile[strlen(cfile) - 3] = 'c';
    if (strcmp(cfile + strlen(cfile) - 4, ".hxx") == 0)
        cfile[strlen(cfile) - 3] = 'c';
    if (strcmp(cfile + strlen(cfile) - 4, ".hpp") == 0)
        cfile[strlen(cfile) - 3] = 'c';
    if (access(cfile, R_OK) == 0)
        if (strcmp(cfile + strlen(cfile) - 2, ".c") == 0)
            func(arg, cfile);

    TALLOC_FREE(context);

    va_end(args);
}
