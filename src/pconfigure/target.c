#include "target.h"

#include "defaults.h"
#include "languages.h"
#include <stdlib.h>
#include <string.h>

#define FREE(x) {free(x) ; x = NULL;}

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

    t->bin_dir = strdup(DEFAULT_CONTEXT_BINDIR);
    t->obj_dir = strdup(DEFAULT_CONTEXT_OBJDIR);
    t->src_dir = strdup(DEFAULT_CONTEXT_SRCDIR);

    t->makefile = NULL;
    t->language = NULL;
    
    t->compile_opts = malloc(sizeof(*(t->compile_opts)));
    if (t->compile_opts == NULL)
	return ERROR_MALLOC_NULL;
    string_list_init(t->compile_opts);

    t->link_opts = malloc(sizeof(*(t->link_opts)));
    if (t->link_opts == NULL)
    {
	string_list_clear(t->compile_opts);
	FREE(t->compile_opts);
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
	    strcat(t->full_path, t->bin_dir);
	    strcat(t->full_path, "/");
	    strcat(t->full_path, t->passed_path);
	    break;
	case TARGET_TYPE_SOURCE:
	    ASSERT_RETURN(t->passed_path != NULL, ERROR_NULL_POINTER);
	    ASSERT_RETURN(t->src_dir != NULL, ERROR_NULL_POINTER);
	    t->full_path = malloc(strlen(t->passed_path)+strlen(t->src_dir)+3);
	    t->full_path[0] = '\0';
	    strcat(t->full_path, t->src_dir);
	    strcat(t->full_path, "/");
	    strcat(t->full_path, t->passed_path);
	    break;
	}
    }

    ASSERT_RETURN(t->full_path != NULL, ERROR_NULL_POINTER);

    /* Attempts to find a language that works for this file */
    if (t->language == NULL)
	t->language = languages_search(t);

    if (t->language == NULL)
    {
	/* FIXME: there is a memory leak here */
	fprintf(stderr, "Could not find a language for '%s'\n", t->full_path);
	return ERROR_ILLEGAL_OP;
    }

    /* Writes the target out to the makefile */
    t->language->write(t->language, t);

    /* Cleans up this target */
    t->type = TARGET_TYPE_NONE;

    FREE(t->bin_dir);
    FREE(t->obj_dir);
    FREE(t->src_dir);

    if (t->passed_path != NULL)
	FREE(t->passed_path);
    if (t->full_path != NULL)
	FREE(t->full_path);

    err = string_list_clear(t->compile_opts);
    FREE(t->compile_opts);
    if (err != ERROR_NONE)
	return err;

    err = string_list_clear(t->link_opts);
    FREE(t->link_opts);
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

    dest->bin_dir = strdup(source->bin_dir);
    dest->obj_dir = strdup(source->obj_dir);
    dest->src_dir = strdup(source->src_dir);

    dest->makefile = NULL;
    dest->language = NULL;

    dest->compile_opts = malloc(sizeof(*(dest->compile_opts)));
    if (dest->compile_opts == NULL)
	return ERROR_MALLOC_NULL;
    err = string_list_copy(dest->compile_opts, source->compile_opts);
    if (err != ERROR_NONE)
    {
	FREE(dest->compile_opts);
	return err;
    }

    dest->link_opts = malloc(sizeof(*(dest->link_opts)));
    if (dest->link_opts == NULL)
    {
	string_list_clear(dest->compile_opts);
	FREE(dest->compile_opts);
	dest->compile_opts = NULL;
	return ERROR_MALLOC_NULL;
    }
    err = string_list_copy(dest->link_opts, source->link_opts);
    if (err != ERROR_NONE)
    {
	string_list_clear(dest->compile_opts);
	FREE(dest->compile_opts);
	dest->compile_opts = NULL;
	FREE(dest->link_opts);
	dest->link_opts = NULL;
	return err;
    }

    return ERROR_NONE;
}
