
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

#ifndef TARGET_STACK_H
#define TARGET_STACK_H

#include "error.h"
#include "target.h"

/* A single stack of targets, pretty much just a place-holder for the methods
   here. */
struct target_stack
{
    struct target *head;
};

/* Initializes the target_stack module target_boot must have been called
   before this was */
enum error target_stack_boot(void);

/* Initailizes a single target stack */
enum error target_stack_init(struct target_stack *s);
enum error target_stack_clear(struct target_stack *s);

/* Creates a new entry on the target stack */
enum error target_stack_push(struct target_stack *s);

/* Looks at the current top of the target stack */
struct target *target_stack_peek(struct target_stack *s);

/* Removes (and frees) an entry from the top of the target stack */
enum error target_stack_pop(struct target_stack *s);

#endif
