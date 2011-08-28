#include "context_stack.h"
#include "context.h"

#include <assert.h>
#include <stdlib.h>

static struct context *frame_to_context(const struct context_stack_frame *f)
{
    return (struct context *)&(f->context);
}

void context_stack_init(struct context_stack *stack)
{
    assert(stack != NULL);

    stack->top = malloc(sizeof(*(stack->top)));
    context_init(frame_to_context(stack->top));

    stack->top->parent = NULL;
}

void context_stack_clear(struct context_stack *stack)
{
    while (stack->top != NULL)
    {
        struct context_stack_frame *parent;

        printf("context_stack freeing\n");
        parent = stack->top->parent;
        context_clear(frame_to_context(stack->top));
        free(stack->top);
        stack->top = parent;
    }
}

struct context *context_stack_peek(const struct context_stack *stack)
{
    if (stack == NULL)
        return NULL;

    return frame_to_context(stack->top);
}
