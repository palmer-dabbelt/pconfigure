
/*
 * Copyright (C) 2013 Palmer Dabbelt
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

#ifndef LIBLIST_H
#define LIBLIST_H

struct liblist;

#include <stdio.h>
#include <stdbool.h>
#include "stringlist.h"

struct liblist_node
{
    struct liblist_node *next;

    /* This is the SHORT name of the library.  For example, "libm.so"
     * has the short name of "m". */
    const char *name;

    /* This contains a list of all the dependencies of this library.
     * This list has already been expanded by recursion. */
    struct stringlist *deps;
};

struct liblist
{
    struct liblist_node *head;
};

/* Allocates a new liblist, passed the parent context */
extern struct liblist *liblist_new(void *context);

/* Adds an entry to the given liblist */
extern int liblist_add(struct liblist *l, const char *name);

/* Searches the given list for the given library name, and then adds
 * the given dependency name to that list. */
extern int liblist_add_dep_ifnew(struct liblist *l,
                                 const char *name, const char *dep);

/* Searches the given list for the given library name, and then calls
the given function for every dependency of that library. */
extern int liblist_each(struct liblist *l, const char *name,
                        int (*func) (const char *, void *), void *arg);

/* Adds every library to the given string list if it's a new
 * library. */
extern int liblist_add_to_sl_ifnew(struct liblist *l, const char *name,
                                   struct stringlist *add_to);

static inline struct liblist_node *liblist_start(struct liblist *l)
{
    return l->head;
}

static inline bool liblist_notend(struct liblist_node *c)
{
    return c != NULL;
}

static inline const char *liblist_name(struct liblist_node *c)
{
    return c->name;
}

static inline struct stringlist *liblist_deps(struct liblist_node *c)
{
    return c->deps;
}

static inline struct liblist_node *liblist_next(struct liblist_node *c)
{
    return c->next;
}

#endif
