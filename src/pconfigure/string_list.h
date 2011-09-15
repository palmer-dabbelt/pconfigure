#ifndef STRING_LIST_H
#define STRING_LIST_H

#include "error.h"
#include <stdio.h>

struct string_list_node
{
    struct string_list_node *next;
    char *data;
};
struct string_list
{
    struct string_list_node *head;
};

/* Initializes the string_list module */
enum error string_list_boot(void);

/* Initializes (or clears) a new (empty) string_list */
enum error string_list_init(struct string_list *l);
enum error string_list_clear(struct string_list *l);

/* Duplicates a string_list into another string_list */
enum error string_list_copy(struct string_list *s, struct string_list *d);

/* Adds an entry to the given string_list */
enum error string_list_add(struct string_list *l, const char *to_add);

/* Removes a string from the given list */
enum error string_list_del(struct string_list *l, const char *to_del);

/* Writes the given string_list out to the given file, seperated by sep */
enum error string_list_fserialize(struct string_list *l, FILE * f,
                                  const char *sep);

/* Checks if the given string is in the given string list */
enum error string_list_include(struct string_list *l, const char *s);

#endif
