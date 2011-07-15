#ifndef LANGUAGE_LIST_H
#define LANGUAGE_LIST_H

/* Language-lists are slightly different than regular linked lists in that they
   really store a subset of the languages availiable.  This allows us to
   easily search for languages so we can use them.  Language lists are NOT
   deep-free'd or deep-clone'd, so the language classes all are permenant
   throughout the entire run of the system. */

struct language_list
{
    struct language_list_node *head;
};

struct language_list_node
{
    struct language *lang;

    struct language_list_node *next;
};

/* Initializes the global language list, this must be called exactly once
	 before using any of the other methods in this file */
void language_list_boot(void);

/* Initializes a new non-global langage list */
void language_list_init(struct language_list *list);

/* Adds a new language list to a sub-list, returns 0 on success */
int language_list_add(struct language_list *list, const char *name);

/* Removes a language list from a sub-list, returns 0 on success */
int language_list_remove(struct language_list *list, const char *name);

/* Searches a sub-list for a language based on the filename */
struct language *language_list_search(const struct language_list *list,
                                      const char *filename);

#endif
