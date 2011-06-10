#ifndef VOID_LIST_H
#define VOID_LIST_H

/* Contains a list of voids, that can be added to and deleted from.  Entries
   are stored in arbitrary order. */
struct void_list
{
	struct void_list_node * head;
};
   
struct void_list_node
{
	struct void_list_node * next;
	void * data;
};

/* Returns true when 2 entries match */
typedef int (*voidlist_match_func_t)(void *, void *);

/* Copies the data from one entry to another, allocating if necessary */
typedef void * (*voidlist_copy_func_t)(void *);

/* Frees a node (could be overloaded nodes that need more space, or
   have more things to deep-free) or allocates one */
typedef struct void_list_node * (*voidlist_alloc_func_t)(void);
typedef void (*voidlist_free_func_t)(struct void_list_node *);

/* These methods all pretty much do what they say.  Copies and clears are deep.
   */
void void_list_init(struct void_list * list);

void void_list_copy(struct void_list * target,
										voidlist_copy_func_t copy,
										const struct void_list * source);
										
void void_list_add(struct void_list * list, const void * toadd);

int void_list_remove(struct void_list * list,
										 voidlist_match_func_t match,
										 voidlist_free_func_t tofree,
										 const void * tofind);
										 
void void_list_clear(struct void_list * list,
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
