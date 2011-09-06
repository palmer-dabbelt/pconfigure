#include "target.h"

#include <stdlib.h>
#include <string.h>

enum error target_boot(void)
{
    return ERROR_NONE;
}

enum error target_init(struct target * t)
{
    ASSERT_RETURN(t != NULL, ERROR_NULL_POINTER);

    t->parent = NULL;
    t->type = TARGET_TYPE_NONE;
    t->passed_path = NULL;
    t->full_path = NULL;

    t->bin_dir = NULL;
    t->src_dir = NULL;

    t->makefile = NULL;
    
    t->compile_opts = malloc(sizeof(*(t->compile_opts)));
    if (t->compile_opts == NULL)
	return ERROR_MALLOC_NULL;
    string_list_init(t->compile_opts);

    t->link_opts = malloc(sizeof(*(t->link_opts)));
    if (t->link_opts == NULL)
    {
	string_list_clear(t->compile_opts);
	free(t->compile_opts);
	t->compile_opts = NULL;
	return ERROR_MALLOC_NULL;
    }
    string_list_init(t->link_opts);

    return ERROR_NONE;
}

enum error target_clear(struct target * t)
{
    enum error err;
    
    /* This is the full path to the target (ie, including "bin/" or "src/") */
    if (t->full_path == NULL)
    {
	switch (t->type)
	{
	case TARGET_TYPE_NONE:
	    t->full_path = NULL;
	    break;
	case TARGET_TYPE_BINARY:
	    ASSERT_RETURN(t->passed_path != NULL, ERROR_NULL_POINTER);
	    ASSERT_RETURN(t->bin_dir != NULL, ERROR_NULL_POINTER);
	    t->full_path = malloc(strlen(t->passed_path)+strlen(t->bin_dir)+3);
	    t->full_path[0] = '\0';
	    strcat(t->full_path, t->passed_path);
	    strcat(t->full_path, "/");
	    strcat(t->full_path, t->bin_dir);
	    break;
	case TARGET_TYPE_SOURCE:
	    ASSERT_RETURN(t->passed_path != NULL, ERROR_NULL_POINTER);
	    ASSERT_RETURN(t->src_dir != NULL, ERROR_NULL_POINTER);
	    t->full_path = malloc(strlen(t->passed_path)+strlen(t->src_dir)+3);
	    t->full_path[0] = '\0';
	    strcat(t->full_path, t->passed_path);
	    strcat(t->full_path, "/");
	    strcat(t->full_path, t->src_dir);
	    break;
	}
    }

    

    /* Writes the target out to the makefile */
    

    /* Cleans up this target */
    t->type = TARGET_TYPE_NONE;

    if (t->passed_path != NULL)
    {
	free(t->passed_path);
	t->passed_path = NULL;
    }
    if (t->full_path != NULL)
    {
	free(t->full_path);
	t->full_path = NULL;
    }

    err = string_list_clear(t->compile_opts);
    if (err != ERROR_NONE)
	return err;

    err = string_list_clear(t->link_opts);
    if (err != ERROR_NONE)
	return err;
    
    return ERROR_NONE;
}

enum error target_copy(struct target *dest, struct target *source)
{
    enum error err;

    ASSERT_RETURN(dest != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(source != NULL, ERROR_NULL_POINTER);

    dest->type = TARGET_TYPE_NONE;
    dest->passed_path = NULL;
    dest->full_path = NULL;

    dest->compile_opts = malloc(sizeof(*(dest->compile_opts)));
    if (dest->compile_opts == NULL)
	return ERROR_MALLOC_NULL;
    err = string_list_copy(dest->compile_opts, source->compile_opts);
    if (err != ERROR_NONE)
    {
	free(dest->compile_opts);
	return err;
    }

    dest->link_opts = malloc(sizeof(*(dest->link_opts)));
    if (dest->link_opts == NULL)
    {
	string_list_clear(dest->compile_opts);
	free(dest->compile_opts);
	dest->compile_opts = NULL;
	return ERROR_MALLOC_NULL;
    }
    err = string_list_copy(dest->link_opts, source->link_opts);
    if (err != ERROR_NONE)
    {
	string_list_clear(dest->compile_opts);
	free(dest->compile_opts);
	dest->compile_opts = NULL;
	free(dest->link_opts);
	dest->link_opts = NULL;
	return err;
    }

    return ERROR_NONE;
}
