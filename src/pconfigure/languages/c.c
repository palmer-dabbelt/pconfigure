#include "c.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static struct language_c * lang = NULL;

enum error language_c_boot(void)
{
    enum error err;
    
    ASSERT_RETURN(lang == NULL, ERROR_ALREADY_BOOT);
    
    lang = malloc(sizeof(*lang));
    ASSERT_RETURN(lang != NULL, ERROR_MALLOC_NULL);

    err = language_init(&(lang->l));
    if (err != ERROR_NONE)
	return err;

    lang->l.name = strdup("c");

    return ERROR_NONE;
}

enum error language_c_halt(void)
{
    enum error err;

    free(lang->l.name);
    lang->l.name = NULL;

    err = language_clear(&(lang->l));
    if (err != ERROR_NONE)
	return err;

    free(lang);
    lang = NULL;

    return ERROR_NONE;
}

struct language * language_c_add(const char * name)
{
    if (strcmp(name, lang->l.name) == 0)
	return &(lang->l);

    return NULL;
}
