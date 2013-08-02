
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

/* Removes a string from the given list */
extern int stringlist_del(struct stringlist *l, const char *to_del);

/* Checks if the given string is in the given string list */
extern bool stringlist_include(struct stringlist *l, const char *s);

/* Returns a hash code for a given string list */
extern const char *stringlist_hashcode(struct stringlist *l, void *context);

/* Returns the number of elements in this list */
extern int stringlist_size(struct stringlist *l);

/* Calls the given function for every element in the list */
extern int stringlist_each(struct stringlist *l, int (*func) (const char *));

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
