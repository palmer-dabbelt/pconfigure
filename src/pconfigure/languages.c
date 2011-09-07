#include "languages.h"

#include <stdio.h>
#include <stdlib.h>

#include "languages/c.h"

#define FREE(x) {free(x); x = NULL;}

/* The last language to be added, used for COMPILEOPTS */
static struct language * last_added;

/* A list of all the languages in the system, used to search for which ones
   should be used to compile */
struct language_list
{
    struct language_list * next;
    struct language * lang;
};
static struct language_list * list;

enum error languages_boot(void)
{
    enum error err;

    err = language_c_boot();
    if (err != ERROR_NONE)
	return err;

    last_added = NULL;
    list = NULL;

    return ERROR_NONE;
}

enum error languages_halt(void)
{
    enum error err;
    struct language_list * cur;

    cur = list;
    while (cur != NULL)
    {
	struct language_list * next;

	next = cur->next;
	FREE(cur);
	cur = next;
    }

    err = language_c_halt();
    if (err != ERROR_NONE)
	return err;

    return ERROR_NONE;
}

enum error languages_add(const char * name)
{
    struct language * ret, * ret_good;

    /* Searches for a language that can match this languages' name */
    ret_good = NULL;

    ret = language_c_add(name);
    if (ret != NULL)
	ret_good = ret;

    /* If a language was found, add it to the list */
    if (ret_good != NULL)
    {
	struct language_list * new;
	last_added = ret_good;
	
	new = malloc(sizeof(*new));
	ASSERT_RETURN(new != NULL, ERROR_MALLOC_NULL);
	new->next = list;
	new->lang = last_added;
	list = new;

	return ERROR_NONE;
    }

    fprintf(stderr, "Language '%s' does not exist\n", name);
    return ERROR_FILE_NOT_FOUND;
}

struct language * languages_last_added(void)
{
    return last_added;
}
