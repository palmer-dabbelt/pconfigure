#include "string_list.h"

#include <assert.h>
#include <stdlib.h>

void void_list_init(struct void_list * list)
{
	assert(list != NULL);
	
	list->head = NULL;
}
