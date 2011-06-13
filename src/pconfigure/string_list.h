#ifndef STRING_LIST_H
#define STRING_LIST_H

#include "void_list.h"

/* Contains a list of voids, that can be added to and deleted from.  Strings
   are stored in arbitrary order. */
struct string_list
{
	struct void_list vl;
};
   
struct string_list_node
{
	struct void_list_node vln;
};

/* These methods all pretty much do what they say.  Copies and clears are deep.
   Everything returns 0 on success and 1 on failure */
int string_list_init(struct string_list * list);
int string_list_copy(struct string_list * target,
										 const struct string_list * source);
int string_list_add(struct string_list * list, const char * toadd);
int string_list_remove(struct string_list * list, const char * tofind);
int string_list_clear(struct string_list * list);

/* This serializes the string list into a buffer, seperated by a given string.
   The method returns 0 on success, and the size of the buffer that would be
   required in order to serialize the entire string on failure. */
unsigned int string_list_serialize(struct string_list * list,
																	 char * buffer, unsigned int size,
																	 const char * seperator);

/* This searches the list for a given string.  It returns -1 if no found, and
   otherwise it returns the index of the string in the list. */
int string_list_search(struct string_list * list, const char * tofind);

/* This adds a string to the list if and only if it does not already exist.  It
   returns 0 on success and 1 on failure. */
int string_list_addifnew(struct string_list * list, const char * toadd);

#endif
