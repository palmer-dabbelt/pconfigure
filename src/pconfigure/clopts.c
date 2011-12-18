
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

#include "clopts.h"
#include <talloc.h>

struct clopts *clopts_new(int argc, char **argv)
{
    struct clopts *o;

    o = talloc(NULL, struct clopts);
    if (o == NULL)
        return NULL;

    o->infile_count = 1;
    o->infiles = talloc_array(o, const char *, o->infile_count);
    o->infiles[0] = talloc_strdup(o, "Configfile");

    o->outfile = talloc_strdup(o, "Makefile");

    return o;
}
