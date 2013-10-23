
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

#ifndef STRINGLIST_H
#define STRINGLIST_H

struct stringlist;

#include "liblist.h"

#include <stdio.h>
#include <stdbool.h>

struct stringlist_node
{
    struct stringlist_node *next;
    const char *data;
};

struct stringlist
{
    struct stringlist_node *head;
};

/* Allocates a new stringlist, passed the parent context */
extern struct stringlist *stringlist_new(void *context);

/* Copies a stringlist, creating copies of each node and references to each
 * string in the list.  The new list will be allocated as a child of context,
 * and all other allocations will be a child of the new list. */
extern struct stringlist *stringlist_copy(struct stringlist *l,
                                          void *context);

/* Adds an entry to the given stringlist */
extern int stringlist_add(struct stringlist *l, const char *to_add);
extern int stringlist_add_ifnew(struct stringlist *l, const char *to_add);

/* Adds an entire stringlist to this stinglist, but only if it's a new
 * item. */
extern int stringlist_addl_ifnew(struct stringlist *to,
                                 struct stringlist *fr);

/* Removes a string from the given list */
extern int stringlist_del(struct stringlist *l, const char *to_del);

/* Checks if the given string is in the given string list */
extern bool stringlist_include(struct stringlist *l, const char *s);

/* Searches the given list for a string that starts with the given
 * substring, returning the first one found (allocated as a
 * sub-context of ctx).  */
extern const char *stringlist_search_start(struct stringlist *l,
                                           const char *s, void *ctx);

/* Returns a hash code for a given string list */
extern const char *stringlist_hashcode(struct stringlist *l, void *context);

/* Returns the number of elements in this list */
extern int stringlist_size(struct stringlist *l);

/* Calls the given function for every element in the list */
extern int stringlist_each(struct stringlist *l,
                           int (*func) (const char *, void *), void *arg);

/* Returns a new stringlist with the given string removed, if it exists. */
extern struct stringlist *stringlist_without(struct stringlist *in,
                                             void *ctx, const char *str);

/* Converts a stringlist to an array of string pointers, assuming the
 * array of pointers has already been allocated.  Memory is allocated
 * as a sub-context of "array", and members are filled it starting at
 * "index".  Returns the last index in the array to be touched. */
extern size_t stringlist_to_alloced_array(struct stringlist *l,
                                          char **array, size_t index);

/* Calls "fprintf(f, format, cur->data)" on every element of this
 * string list -- note that that means that "format" is going to have
 * to have exactly one %s in it. */
extern void stringlist_fprintf(struct stringlist *l, FILE * f,
                               const char *format);

/* Adds every element in the given string list to the given
 * liblist, under the given lib name. */
extern void stringlist_add_to_liblist(struct stringlist *l,
                                      struct liblist *ll,
                                      const char *lib_name);

static inline struct stringlist_node *stringlist_start(struct stringlist *l)
{
    return l->head;
}

static inline bool stringlist_notend(struct stringlist_node *c)
{
    return c != NULL;
}

static inline const char *stringlist_data(struct stringlist_node *c)
{
    return c->data;
}

static inline struct stringlist_node *stringlist_next(struct stringlist_node
                                                      *c)
{
    return c->next;
}

#endif
