#include "context_stack.h"
#include "context.h"

#include <assert.h>
#include <stdlib.h>

static struct context * frame_to_context(const struct context_stack_frame * f)
{
	return (struct context *)f;
}

void context_stack_init(struct context_stack * stack)
{
	assert(stack != NULL);
	
	stack->top = malloc(sizeof(*(stack->top)));
	context_init(frame_to_context(stack->top));
	
	stack->top->parent = NULL;
}

struct context * context_stack_peek(const struct context_stack * stack)
{
	if (stack == NULL)
		return NULL;
	
	return frame_to_context(stack->top);
}
