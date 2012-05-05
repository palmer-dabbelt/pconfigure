
/*
 * Copyright (C) 2011 Daniel Dabbelt
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

#include "contextstack.h"
#include <talloc.h>
#include <assert.h>

struct contextstack *contextstack_new(struct clopts *o,
                                      struct makefile *mf,
                                      struct languagelist *ll)
{
    struct contextstack *s;

    s = talloc(o, struct contextstack);
    if (s == NULL)
        return NULL;

    s->head = talloc(s, struct contextstack_node);
    if (s->head == NULL)
    {
        TALLOC_FREE(s);
        return NULL;
    }

    s->head->data = context_new_defaults(o, s->head, mf, ll, s);
    if (s->head->data == NULL)
    {
        TALLOC_FREE(s);
        return NULL;
    }
    s->head->next = NULL;

    return s;
}

bool contextstack_isempty(struct contextstack * s)
{
    if (s == NULL)
        return true;
    if (s->head == NULL)
        return true;
    if (s->head->next == NULL)
        return true;

    return false;
}

struct context *contextstack_pop(struct contextstack *s, void *context)
{
    struct context *c;
    struct contextstack_node *cur;

    if (s == NULL)
        return NULL;
    if (s->head == NULL)
        return NULL;
    if (s->head->next == NULL)
        return NULL;

    assert(s->head->data != NULL);
    c = talloc_reference(context, s->head->data);
    cur = s->head;
    s->head = s->head->next;

    TALLOC_FREE(cur);
    return c;
}

struct context *contextstack_peek(struct contextstack *s, void *context)
{
    if (s == NULL)
        return NULL;
    if (context == NULL)
        return NULL;

    if (contextstack_isempty(s))
        return NULL;

    assert(s->head->data != NULL);
    return talloc_reference(context, s->head->data);
}

struct context *contextstack_peek_default(struct contextstack *s,
                                          void *context)
{
    if (s == NULL)
        return NULL;
    if (context == NULL)
        return NULL;

    assert(s->head->data != NULL);
    return talloc_reference(context, s->head->data);
}

void contextstack_push_binary(struct contextstack *s, const char *called_path)
{
    struct contextstack_node *cur;
    struct context *c;

    if (s == NULL)
        return;
    if (called_path == NULL)
        return;

    cur = talloc(s, struct contextstack_node);
    if (cur == NULL)
        abort();

    /* Creates a new context, based on the current context */
    c = context_new_binary(s->head->data, cur, called_path);
    if (c == NULL)
    {
        TALLOC_FREE(cur);
        abort();
    }

    /* This context is the new head. */
    cur->data = c;
    cur->next = s->head;
    s->head = cur;
}

void contextstack_push_source(struct contextstack *s, const char *called_path)
{
    struct contextstack_node *cur;
    struct context *c;

    if (s == NULL)
    {
        abort();
        return;
    }
    if (called_path == NULL)
        return;

    cur = talloc(s, struct contextstack_node);
    if (cur == NULL)
        abort();

    /* Creates a new context, based on the current context */
    c = context_new_source(s->head->data, cur, called_path);
    if (c == NULL)
    {
        TALLOC_FREE(cur);
        abort();
    }

    /* This context is the new head. */
    cur->data = c;
    cur->next = s->head;
    s->head = cur;
}
