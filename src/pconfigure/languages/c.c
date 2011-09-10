#include "c.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define FREE(x) {free(x); x = NULL;}

static struct language_c *lang = NULL;

/* Functions that fill out the lang structure */
static struct language *l_search(struct language_c *l, struct target *t);
static enum error l_write(struct language_c *l, struct target *t);

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
    lang->l.extension = strdup(".c");

    lang->l.search = (language_func_search) & l_search;
    lang->l.write = (language_func_write) & l_write;

    return ERROR_NONE;
}

enum error language_c_halt(void)
{
    enum error err;

    FREE(lang->l.name);
    FREE(lang->l.extension);

    err = language_clear(&(lang->l));
    if (err != ERROR_NONE)
        return err;

    FREE(lang);

    return ERROR_NONE;
}

struct language *language_c_add(const char *name)
{
    if (strcmp(name, lang->l.name) == 0)
        return &(lang->l);

    return NULL;
}

/* These functions fill out the language struct */
struct language *l_search(struct language_c *l, struct target *t)
{
    ASSERT_RETURN(t->full_path != NULL, NULL);
    ASSERT_RETURN(t->parent != NULL, NULL);

    if (t->parent->language != NULL)
        if (strcmp(t->parent->language->name, l->l.name) != 0)
            return NULL;

    if (strcmp(t->full_path + strlen(t->full_path) - strlen(l->l.extension),
               l->l.extension) == 0)
    {
        t->parent->language = (struct language *)l;
        return (struct language *)l;
    }

    return NULL;
}

enum error l_write(struct language_c *l, struct target *t)
{
    RETURN_UNIMPLEMENTED;
}
