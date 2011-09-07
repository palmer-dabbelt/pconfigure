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
    struct target * t;
    
    ASSERT_RETURN(s != NULL, ERROR_NULL_POINTER);

    t = malloc(sizeof(*t));
    if (t == NULL)
	return ERROR_MALLOC_NULL;

    if (s->head == NULL)
	err = target_init(t);
    else
	err = target_copy(t, s->head);

    if (err != ERROR_NONE)
    {
	FREE(t);
	return err;
    }

    t->parent = s->head;
    s->head = t;

    return ERROR_NONE;
}

struct target * target_stack_peek(struct target_stack *s)
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
    if (err != ERROR_NONE)
	return err;

    s->head = new_head;
    FREE(t);
    
    return ERROR_NONE;
}
