
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

#include "string_list.h"

#include <stdlib.h>
#include <string.h>

#include "error.h"

#define FREE(x) {free(x); x = NULL;}

enum error string_list_boot(void)
{
    return ERROR_NONE;
}

enum error string_list_init(struct string_list *l)
{
    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);

    l->head = NULL;

    return ERROR_NONE;
}

enum error string_list_clear(struct string_list *l)
{
    struct string_list_node *cur;

    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);

    cur = l->head;
    while (cur != NULL)
    {
        struct string_list_node *next;

        next = cur->next;
        FREE(cur->data);
        FREE(cur);

        cur = next;
    }

    l->head = NULL;

    return ERROR_NONE;
}

enum error string_list_add(struct string_list *l, const char *to_add)
{
    struct string_list_node *new, *cur;

    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(to_add != NULL, ERROR_NULL_POINTER);

    new = malloc(sizeof(*new));
    if (new == NULL)
        return ERROR_MALLOC_NULL;

    new->data = strdup(to_add);
    new->next = NULL;

    if (l->head == NULL)
    {
        l->head = new;
        return ERROR_NONE;
    }

    cur = l->head;
    while (cur->next != NULL)
        cur = cur->next;

    cur->next = new;

    return ERROR_NONE;
}

enum error string_list_del(struct string_list *l, const char *to_del)
{
    RETURN_UNIMPLEMENTED;
}

enum error string_list_copy(struct string_list *dst, struct string_list *src)
{
    struct string_list_node *cur;

    ASSERT_RETURN(dst != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(src != NULL, ERROR_NULL_POINTER);

    dst->head = NULL;
    cur = src->head;
    while (cur != NULL)
    {
        enum error err;

        err = string_list_add(dst, cur->data);
        if (err != ERROR_NONE)
        {
            string_list_clear(dst);
            return err;
        }
        cur = cur->next;
    }

    return ERROR_NONE;
}

enum error string_list_include(struct string_list *l, const char *s)
{
    struct string_list_node *cur;

    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(s != NULL, ERROR_NULL_POINTER);

    cur = l->head;
    while (cur != NULL)
    {
        ASSERT_RETURN(cur->data != NULL, ERROR_NULL_POINTER);

        if (strcmp(cur->data, s) == 0)
            return ERROR_ALREADY_EXISTS;

        cur = cur->next;
    }

    return ERROR_NONE;
}
