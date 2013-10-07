
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
#include "../lambda.h"
#include <string.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

static struct language *language_cxx_search(struct language *l_uncast,
                                            struct language *parent,
                                            const char *path);
static void language_cxx_extras(struct language *l_uncast, struct context *c,
                                void *context, void (*func) (const char *));

struct language *language_cxx_new(struct clopts *o, const char *name)
{
    struct language *l;

    if (strcmp(name, "c++") != 0)
        return NULL;

    l = language_c_new(o, "c");
    if (l == NULL)
        return NULL;

    l->name = talloc_strdup(l, "c++");
    l->compiled = true;
    l->compile_str = talloc_strdup(l, "C++");
    l->compile_cmd = talloc_strdup(l, "${CXX}");
    l->link_str = talloc_strdup(l, "LD++");
    l->link_cmd = talloc_strdup(l, "${CXX}");
    l->search = &language_cxx_search;
    l->extras = &language_cxx_extras;

    return l;
}

struct language *language_cxx_search(struct language *l_uncast,
                                     struct language *parent,
                                     const char *path)
{
    struct language_c *l;

    l = talloc_get_type(l_uncast, struct language_c);
    if (l == NULL)
        return NULL;

    if ((strcmp(path + strlen(path) - 4, ".c++") != 0) &&
        (strcmp(path + strlen(path) - 4, ".cxx") != 0) &&
        (strcmp(path + strlen(path) - 4, ".cpp") != 0))
        return NULL;

    if (parent == NULL)
        return l_uncast;

    if (strcmp(parent->link_name, l_uncast->link_name) != 0)
        return NULL;

    return l_uncast;
}

void language_cxx_extras(struct language *l_uncast, struct context *c,
                         void *context, void (*func) (const char *))
{
    /* *INDENT-OFF* */
    language_deps(l_uncast, c, 
		  lambda(void, (const char *format, ...),
			 {
			     va_list args;
			     char *cfile;
			     char *cxxfile;

			     va_start(args, format);

			     cfile = talloc_vasprintf(context, format, args);

			     cxxfile = talloc_array(context, char,
						    strlen(cfile) + 20);

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

			     memset(cxxfile, 0, strlen(cfile) + 10);
			     strncpy(cxxfile, cfile, strlen(cfile) - 4);
			     strcat(cxxfile, ".c++");
			     if (access(cxxfile, R_OK) == 0)
				 func(cxxfile);

			     memset(cxxfile, 0, strlen(cfile) + 10);
			     strncpy(cxxfile, cfile, strlen(cfile) - 4);
			     strcat(cxxfile, ".cxx");
			     if (access(cxxfile, R_OK) == 0)
				 func(cxxfile);

			     memset(cxxfile, 0, strlen(cfile) + 10);
			     strncpy(cxxfile, cfile, strlen(cfile) - 4);
			     strcat(cxxfile, ".cpp");
			     if (access(cxxfile, R_OK) == 0)
				 func(cxxfile);

			     if (strcmp(cfile + strlen(cfile) - 2, ".h") == 0)
				 cfile[strlen(cfile)-1] = 'c';
			     if (strcmp(cfile + strlen(cfile) - 4, ".h++") == 0)
				 cfile[strlen(cfile)-3] = 'c';
			     if (strcmp(cfile + strlen(cfile) - 4, ".hxx") == 0)
				 cfile[strlen(cfile)-3] = 'c';
			     if (strcmp(cfile + strlen(cfile) - 4, ".hpp") == 0)
				 cfile[strlen(cfile)-3] = 'c';
			     if (access(cfile, R_OK) == 0)
				 if (strcmp(cfile + strlen(cfile) - 2, ".c") == 0)
				     func(cfile);
			     
			     va_end(args);
			 }
		      ));
    /* *INDENT-ON* */
}
