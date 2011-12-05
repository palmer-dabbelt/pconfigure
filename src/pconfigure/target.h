
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

#ifndef TARGET_H
#define TARGET_H

#include "error.h"
#include "string_list.h"
#include "makefile.h"
#include "languages/language.h"

enum target_type
{
    TARGET_TYPE_NONE = 0,
    TARGET_TYPE_BINARY,
    TARGET_TYPE_SOURCE
};

/* Holds a single "target" (which can be a TARGET, SOURCE, etc) */
struct target
{
    /* Targets are a n-tree that goes from child->parent (so the reverse mapping
     * is stored) */
    struct target *parent;

    /* Targets all have a type */
    enum target_type type;

    /* Paths that can be set with options */
    char *bin_dir;
    char *obj_dir;
    char *src_dir;
    char *prefix;

    /* The path passed when this target was created */
    char *passed_path;

    /* The actual full path to the source (or binary, or library, etc) that
     * this target represents */
    char *full_path;

    /* Targets can have their own options */
    struct string_list *compile_opts;
    struct string_list *link_opts;

    /* Each target can have a list of dependencies */
    struct string_list *deps;

    /* Every target needs to be written to a makefile */
    struct makefile *makefile;

    /* Every target has one language associated with it */
    struct language *language;
};

/* Initializes the target module */
enum error target_boot(void);

/* Initializes a single target, starts as completely empty */
enum error target_init(struct target *t);

/* Clears out a target, writing the required bits to the makefile in order
   to actually build the target.
   _nowrite does not call language->write, so needs to be used from within
   the implementation of l_write. */
enum error target_clear(struct target *t);
enum error target_clear_nowrite(struct target *t);

/* Copies target "source" into target "dest" */
enum error target_copy(struct target *dest, struct target *source);

#endif
