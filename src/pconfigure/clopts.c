
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

#include "clopts.h"
#include <talloc.h>
#include <string.h>

struct clopts *clopts_new(int argc, char **argv)
{
    struct clopts *o;
    int i;

    o = talloc(NULL, struct clopts);
    if (o == NULL)
        return NULL;

    o->infile_count = 2;
    o->infiles = talloc_array(o, const char *, o->infile_count);
    o->infiles[0] = talloc_strdup(o, "Configfile.local");
    o->infiles[1] = talloc_strdup(o, "Configfile");

    o->outfile = talloc_strdup(o, "Makefile");

    o->verbose = false;

    for (i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--verbose") == 0)
            o->verbose = true;
        else
        {
            fprintf(stderr, "Unknown argument: '%s'\n", argv[i]);
            abort();
        }
    }

    return o;
}
