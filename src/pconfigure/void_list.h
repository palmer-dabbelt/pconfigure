#ifndef VOID_LIST_H
#define VOID_LIST_H

/* Contains a list of voids, that can be added to and deleted from.  Entries
   are stored in arbitrary order. */
struct void_list
{
	struct void_list_node * head;
	struct void_list_node * tail;
};
   
struct void_list_node
{
	struct void_list_node * next;
	void * data;
};

/* Returns 1 when 2 entries match, 0 otherwise */
typedef int (*voidlist_match_func_t)(const void *, const void *);

/* Copies the data from one entry to another, allocating if necessary */
typedef void * (*voidlist_copy_func_t)(const struct void_list_node *);

/* Frees a node (could be overloaded nodes that need more space, or
   have more things to deep-free) or allocates one */
typedef struct void_list_node * (*voidlist_alloc_func_t)(const void *);
typedef int (*voidlist_free_func_t)(struct void_list_node *);

/* These methods all pretty much do what they say.  Copies and clears are deep.
   The given function pointers are used to allocate, free, and copy */
int void_list_init(struct void_list * list);

int void_list_copy(struct void_list * target,
									 voidlist_copy_func_t copy,
									 const struct void_list * source);
										
int void_list_add(struct void_list * list,
									voidlist_alloc_func_t alloc,
									const void * toadd);

int void_list_remove(struct void_list * list,
										 voidlist_match_func_t match,
										 voidlist_free_func_t tofree,
										 const void * tofind);
										 
int void_list_clear(struct void_list * list,
										voidlist_free_func_t tofree);

/* This searches the list for a given string.  It returns -1 if no found, and
   otherwise it returns the index of the string in the list. */
int void_list_search(struct void_list * list,
										 voidlist_match_func_t match,
										 const void * tofind);

/* This adds a string to the list if and only if it does not already exist.  It
   returns 1 on success and 0 on failure. */
int void_list_addifnew(struct void_list * list,
											 voidlist_match_func_t match,
											 const void * toadd);

#endif
