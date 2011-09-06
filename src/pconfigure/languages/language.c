#include "language.h"

#include <stdlib.h>

#include "../error.h"
#include "../string_list.h"

enum error language_init(struct language * l)
{
    l->name = NULL;
    
    l->compile_opts = malloc(sizeof(*(l->compile_opts)));
    if (l->compile_opts == NULL)
	return ERROR_MALLOC_NULL;
    string_list_init(l->compile_opts);

    l->link_opts = malloc(sizeof(*(l->link_opts)));
    if (l->link_opts == NULL)
    {
	string_list_clear(l->compile_opts);
	free(l->compile_opts);
	return ERROR_MALLOC_NULL;
    }

    return ERROR_NONE;
}
