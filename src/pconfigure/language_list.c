#include "language_list.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>

#include "languages/c.h"
#include "languages/ruby.h"

/* This holds every language that exists in the system, and is populated at
   boot time.  A subset of this is used at any particular time to build the
   list of languages that pconfigure searches to build files.  This allows
   us to support mutually exclusive languages and such. */
static struct language_list ll_all;

void language_list_boot(void)
{
    struct language_list_node *tail;

    /* Start out with an empty list of languages */
    ll_all.head = NULL;

    /* Initializes our adding sequence */
    ll_all.head = malloc(sizeof(*(ll_all.head)));
    tail = ll_all.head;

    /* Adds a bunch of languages */
    if (tail == NULL)
        return;
    tail->lang = language_c_boot();

    tail->next = malloc(sizeof(*(tail->next)));
    tail = tail->next;
    if (tail == NULL)
        return;
    tail->lang = language_ruby_boot();

    /* Ends the list */
    tail->next = NULL;
}

void language_list_init(struct language_list *list)
{
    list->head = NULL;
}

int language_list_add(struct language_list *list, const char *name)
{
    struct language *lang;
    struct language_list_node *cur, *add;

    /* Searches the list of all languages for one to duplicate */
    cur = ll_all.head;
    lang = NULL;
    while (cur != NULL)
    {
        if (strcmp(name, cur->lang->name) == 0)
            lang = cur->lang;

        cur = cur->next;
    }

    /* It's an error if we didn't find a language */
    if (lang == NULL)
    {
        fprintf(stderr, "Language '%s' not found\n", name);
        return 2;
    }

    /* Allocates some space so we can easily add the node in */
    add = malloc(sizeof(*add));
    if (add == NULL)
        return 3;

    add->lang = lang;
    add->next = list->head;
    list->head = add;

    return 0;
}

int language_list_remove(struct language_list *list, const char *name)
{
    return 1;
}

struct language *language_list_search(const struct language_list *list,
                                      const char *filename)
{
    struct language_list_node *cur;

    if (list == NULL)
        return NULL;

    /* Checks every language in the list until we find one that matches */
    cur = list->head;
    while (cur != NULL)
    {
        assert(cur->lang != NULL);

        if (language_match(cur->lang, filename))
            return cur->lang;

        cur = cur->next;
    }

    return NULL;
}
