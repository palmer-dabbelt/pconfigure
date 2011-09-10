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
