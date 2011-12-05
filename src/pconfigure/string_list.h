
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

#ifndef STRING_LIST_H
#define STRING_LIST_H

#include "error.h"
#include <stdio.h>

struct string_list_node
{
    struct string_list_node *next;
    char *data;
};
struct string_list
{
    struct string_list_node *head;
};

/* Initializes the string_list module */
enum error string_list_boot(void);

/* Initializes (or clears) a new (empty) string_list */
enum error string_list_init(struct string_list *l);
enum error string_list_clear(struct string_list *l);

/* Duplicates a string_list into another string_list */
enum error string_list_copy(struct string_list *s, struct string_list *d);

/* Adds an entry to the given string_list */
enum error string_list_add(struct string_list *l, const char *to_add);

/* Removes a string from the given list */
enum error string_list_del(struct string_list *l, const char *to_del);

/* Writes the given string_list out to the given file, seperated by sep */
enum error string_list_fserialize(struct string_list *l, FILE * f,
                                  const char *sep);

/* Checks if the given string is in the given string list */
enum error string_list_include(struct string_list *l, const char *s);

#endif
