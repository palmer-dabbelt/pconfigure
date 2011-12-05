
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

#ifndef MAKEFILE_H
#define MAKEFILE_H

#include "error.h"
#include <stdio.h>
#include "string_list.h"

enum makefile_state
{
    MAKEFILE_STATE_NONE = 0,
    MAKEFILE_STATE_TARGET,
    MAKEFILE_STATE_DEPS,
    MAKEFILE_STATE_DEPS_DONE,
    MAKEFILE_STATE_CMDS
};

struct makefile
{
    /* The current state of the makefile */
    enum makefile_state state;

    /* The file pointer used to write to this makefile.  Don't use this
     * directly, but instead use the methods below */
    FILE *file;

    /* The list of targets to be build when one types "make all" */
    struct string_list *targets_all;

    /* The list of all things that get built, ever */
    struct string_list *build_list;

    /* The list of targets to install */
    struct string_list *install_bin;
    struct string_list *install_dir;
};

/* Call this (only once) before calling any other methods that use makefile */
enum error makefile_boot(void);

/* Opens (or closes) a makefile */
enum error makefile_init(struct makefile *m);
enum error makefile_clear(struct makefile *m);

/* Creates a new target */
enum error makefile_create_target(struct makefile *m, const char *name);

/* Adds a new dependency to a target (_start just changes state, for use with
   raw fd writes) */
enum error makefile_start_deps(struct makefile *m);
enum error makefile_add_dep(struct makefile *m, const char *dep);
enum error makefile_end_deps(struct makefile *m);

/* Adds a new comand for building a target (_start as above) */
enum error makefile_start_cmds(struct makefile *m);
enum error makefile_add_cmd(struct makefile *m, const char *cmd);
enum error makefile_end_cmds(struct makefile *m);

#endif
