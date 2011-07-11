#ifndef CONTEXT_STACK_H
#define CONTEXT_STACK_H

#include "context.h"

/* Stores the stack of pconfigure instances.  This is used for both the 
   INCLUDE functionality and the PUSH/POP commands. */
struct context_stack_frame
{
    /* Allows for a cast instead of a dereference */
    struct context context;

    /* The parent, used to pop */
    struct context_stack_frame *parent;
};

struct context_stack
{
    /* The last stack frame to be push'd */
    struct context_stack_frame *top;
};

/* Initializes a stack of instances.  Stacks are initialized to having one
   frame, whose members are set from the #define's in defaults.h */
void context_stack_init(struct context_stack *stack);

/* Creates a new stack frame on top of the current one.  The values in this
   frame will default to a copy of those in the previous frame */
void context_stack_push(struct context_stack *stack);

/* Removes a stack frame from the given stack.  This can invalidate all pointers
   returned by other methods, so be sure to deep copy them if necessary */
void context_stack_pop(struct context_stack *stack);

/* Returns the current context on the top of the frame.  Note that this context
   and all data inside it will be free'd after a pop, so be sure to make a
   deep copy if (for some reason) you want to keep it around */
struct context *context_stack_peek(const struct context_stack *stack);

#endif
