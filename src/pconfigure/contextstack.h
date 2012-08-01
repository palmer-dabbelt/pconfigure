
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

#ifndef PCONFIGURE_CONTEXTSTACK_H
#define PCONFIGURE_CONTEXTSTACK_H

struct contextstack;

#include "context.h"
#include "clopts.h"
#include "makefile.h"
#include "languagelist.h"
#include <stdbool.h>

struct contextstack_node
{
    struct context *data;
    struct contextstack_node *next;
};

struct contextstack
{
    struct contextstack_node *head;
};

extern struct contextstack *contextstack_new(struct clopts *o,
                                             struct makefile *mf,
                                             struct languagelist *ll);

extern bool contextstack_isempty(struct contextstack *s);

/* Looks at the top of the stack, ..._default() returns the default context if
 * there is no other context to return. */
extern struct context *contextstack_peek(struct contextstack *s,
                                         void *context);
extern struct context *contextstack_peek_default(struct contextstack *s,
                                                 void *context);

extern struct context *contextstack_pop(struct contextstack *s,
                                        void *context);

extern void contextstack_push_binary(struct contextstack *s,
                                     const char *called_path);
extern void contextstack_push_library(struct contextstack *s,
                                      const char *called_path);
extern void contextstack_push_header(struct contextstack *s,
                                     const char *called_path);
extern void contextstack_push_source(struct contextstack *s,
                                     const char *called_path);

#endif
