#ifndef STRING_LIST_H
#define STRING_LIST_H

#include "error.h"

struct string_list_node
{
    struct string_list_node * next;
    char * data;
};
struct string_list
{
    struct string_list_node * head;
};

/* Initializes the string_list module */
enum error string_list_boot(void);

/* Initializes (or clears) a new (empty) string_list */
enum error string_list_init(struct string_list * l);
enum error string_list_clear(struct string_list * l);

/* Duplicates a string_list into another string_list */
enum error string_list_copy(struct string_list * s, struct string_list * d);

/* Adds an entry to the given string_list */
enum error string_list_add(struct string_list * l, const char * to_add);

/* Removes a string from the given list */
enum error string_list_del(struct string_list * l, const char * to_del);

#endif
