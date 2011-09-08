#include "language.h"

#include <stdlib.h>

#include "../error.h"
#include "../string_list.h"

enum error language_init(struct language * l)
{
    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);

    l->name = NULL;
    l->extension = NULL;
    
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
    string_list_init(l->link_opts);

    l->search = NULL;
    l->write = NULL;

    return ERROR_NONE;
}

enum error language_clear(struct language * l)
{
    enum error err;
    
    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);

    err = string_list_clear(l->compile_opts);
    if (err != ERROR_NONE)
	return err;
    free(l->compile_opts);

    err = string_list_clear(l->link_opts);
    if (err != ERROR_NONE)
	return err;
    free(l->link_opts);
    
    return ERROR_NONE;
}
