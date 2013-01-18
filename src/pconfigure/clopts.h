
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

#ifndef PCONFIGURE_CLOPTS_H
#define PCONFIGURE_CLOPTS_H

#include <stdbool.h>

struct clopts
{
    int infile_count;
    const char **infiles;

    const char *outfile;

    bool verbose;

    /* This is the directory in which the sources live */
    const char *source_path;
};

/* Parses the command-line options and creates a new (NULL-parented) list of
 * options. */
extern struct clopts *clopts_new(int argc, char **argv);

#endif
