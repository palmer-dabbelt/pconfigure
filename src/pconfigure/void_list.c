#include "string_list.h"

#include <assert.h>
#include <stdlib.h>

int void_list_init(struct void_list * list)
{
	assert(list != NULL);
	
	list->head = NULL;
	list->tail = NULL;
	
	return 0;
}

int void_list_copy(struct void_list * target,
									 voidlist_copy_func_t copy,
									 const struct void_list * source);
										
int void_list_add(struct void_list * list,
									voidlist_alloc_func_t alloc,
									const void * toadd)
{
	if (list->tail == NULL)
	{
		list->head = alloc(toadd);
		if (list->head == NULL) return -1;
		
		list->tail = list->head;
		list->head->next = NULL;
		
		return 0;
	}
	
	list->tail->next = alloc(toadd);
	if (list->tail->next == NULL) return -1;
	
	list->tail = list->tail->next;
	list->tail->next = NULL;
	
	return 0;
}

int void_list_remove(struct void_list * list,
										 voidlist_match_func_t match,
										 voidlist_free_func_t tofree,
										 const void * tofind)
{
	struct void_list_node * cur, * prev;
	
	if ((list->head == NULL) || (list->tail == NULL))
		return -1;
	
	/* There are 2 special cases, the beginning and the end */
	if (match(tofind, list->head->data))
	{
		struct void_list_node * to_remove;
		
		to_remove = list->head;
		list->head = list->head->next;
		tofree(to_remove);
		
		return 0;
	}
	if (match(tofind, list->tail->data))
	{
		struct void_list_node * new_tail;
		
		/* Finds the proper end of the list */
		new_tail = list->head;
		assert(new_tail != NULL);
		while (new_tail->next != NULL)
			new_tail = new_tail->next;
		
		tofree(list->tail);
		new_tail->next = NULL;
		list->tail = new_tail;
		
		return 0;
	}
	
	/* The node must be in the middle of the list, so just remove it */
	prev = NULL;
	cur = list->head;
	while (cur != NULL)
	{
		if (match(tofind, cur->data))
			break;
		
		prev = cur;
		cur = cur->next;
	}
	
	/* It's possible that the node just doesn't exist at all */
	if (cur == NULL)
		return -1;
	
	/* We know we're not at the head or end of the list, so we can just remove
	   it without any penalties */
	assert(cur != NULL);
	assert(prev != NULL);
	
	prev->next = cur->next;
	tofree(cur);
	
	return 0;
}
										 
int void_list_clear(struct void_list * list,
										voidlist_free_func_t tofree);

/* This searches the list for a given string.  It returns -1 if no found, and
   otherwise it returns the index of the string in the list. */
int void_list_search(struct void_list * list,
										 voidlist_match_func_t match,
										 const void * tofind)
{
	int i;
	struct void_list_node * cur;
	
	i = 0;
	cur = list->head;
	while (cur != NULL)
	{
		if (match(cur->data, tofind) != 0)
			return i;
			
		i++;
		cur = cur->next;
	}
	
	return -1;
}

/* This adds a string to the list if and only if it does not already exist.  It
   returns 1 on success and 0 on failure. */
int void_list_addifnew(struct void_list * list,
											 voidlist_match_func_t match,
											 const void * toadd);
