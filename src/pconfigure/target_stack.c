
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

#include "target_stack.h"

#include "error.h"
#include <stdlib.h>

#define FREE(x) {free(x); x = NULL;}

enum error target_stack_boot(void)
{
    return ERROR_NONE;
}

enum error target_stack_init(struct target_stack *s)
{
    ASSERT_RETURN(s != NULL, ERROR_NULL_POINTER);

    s->head = NULL;

    return ERROR_NONE;
}

enum error target_stack_clear(struct target_stack *s)
{
    ASSERT_RETURN(s != NULL, ERROR_NULL_POINTER);

    while (s->head != NULL)
    {
        enum error err;

        err = target_stack_pop(s);
        if (err != ERROR_NONE)
            return err;
    }

    return ERROR_NONE;
}

enum error target_stack_push(struct target_stack *s)
{
    enum error err;
    struct target *t;

    ASSERT_RETURN(s != NULL, ERROR_NULL_POINTER);

    t = malloc(sizeof(*t));
    ASSERT_RETURN(t != NULL, ERROR_MALLOC_NULL);

    if (s->head == NULL)
        err = target_init(t);
    else
        err = target_copy(t, s->head);

    CHECK_ERROR(err);

    t->parent = s->head;
    s->head = t;

    return ERROR_NONE;
}

struct target *target_stack_peek(struct target_stack *s)
{
    ASSERT_RETURN(s != NULL, NULL);

    return s->head;
}

enum error target_stack_pop(struct target_stack *s)
{
    enum error err;
    struct target *t, *new_head;

    ASSERT_RETURN(s != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(s->head != NULL, ERROR_NULL_POINTER);

    t = s->head;
    new_head = t->parent;

    err = target_clear(t);
    CHECK_ERROR(err);

    s->head = new_head;
    FREE(t);

    return ERROR_NONE;
}
