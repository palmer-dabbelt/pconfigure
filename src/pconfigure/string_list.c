#include "string_list.h"

#include <string.h>
#include <assert.h>
#include <stdlib.h>

/* Accessor methods for string lists */
static inline struct string_list_node *sl_head(struct string_list *sl)
{
    return (struct string_list_node *)(sl->vl.head);
}

static inline char *sln_data(struct string_list_node *sln)
{
    return (char *)(sln->vln.data);
}

static inline struct string_list_node *sln_next(struct string_list_node *sln)
{
    return (struct string_list_node *)(sln->vln.next);
}

/* These are the helper functions for void lists.  Don't change these without
   changing the voidlist declaration because they're just casted so they won't
   get checked in any way by the compiler. */
static int match_func(const char *a, const char *b);
static struct string_list_node *alloc_func(const char *data);
static int free_func(struct string_list_node *node);

int string_list_init(struct string_list *list)
{
    return void_list_init((struct void_list *)list);
}

int string_list_copy(struct string_list *target,
                     const struct string_list *source);

int string_list_add(struct string_list *list, const char *toadd)
{
    return void_list_add((struct void_list *)list,
                         (voidlist_alloc_func_t) & alloc_func, (void *)toadd);
}

int string_list_remove(struct string_list *list, const char *tofind)
{
    return void_list_remove((struct void_list *)list,
                            (voidlist_match_func_t) match_func,
                            (voidlist_free_func_t) free_func, (void *)tofind);
}

int string_list_clear(struct string_list *list)
{
    return void_list_clear((struct void_list *)list,
                           (voidlist_free_func_t) free_func);
}

unsigned int string_list_serialize(struct string_list *list,
                                   char *buffer, unsigned int size,
                                   const char *seperator);

int string_list_fserialize(struct string_list *list,
                           FILE * outfile, const char *seperator)
{
    struct string_list_node *cur;

    if (list == NULL)
        return 1;
    if (outfile == NULL)
        return 2;
    if (seperator == NULL)
        return 3;

    cur = sl_head(list);
    while (cur != NULL)
    {
        fprintf(outfile, "%s", sln_data(cur));
        if (sln_next(cur) != NULL)
            fprintf(outfile, "%s", seperator);

        cur = sln_next(cur);
    }

    return 0;
}

int string_list_search(struct string_list *list, const char *tofind)
{
    return void_list_search((struct void_list *)list,
                            (voidlist_match_func_t) & match_func,
                            (void *)tofind);
}

int string_list_addifnew(struct string_list *list, const char *toadd)
{
    assert(list != NULL);

    if (string_list_search(list, toadd) == -1)
        return string_list_add(list, toadd);

    return 1;
}

/* Static functions */
int match_func(const char *a, const char *b)
{
    assert(a != NULL);
    assert(b != NULL);
    return strcmp(a, b) == 0;
}

struct string_list_node *alloc_func(const char *data)
{
    struct string_list_node *out;

    out = malloc(sizeof(*out));
    if (out == NULL)
        return NULL;

    out->vln.data = strdup(data);

    return out;
}

int free_func(struct string_list_node *node)
{
    assert(node != NULL);
    assert(node->vln.data != NULL);

    free(node->vln.data);
    free(node);

    return 0;
}
