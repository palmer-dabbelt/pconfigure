#include "target.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

int target_init(struct target *t)
{
    t->type = TARGET_TYPE_NONE;
    t->target = NULL;
    t->source = NULL;
    t->parent = NULL;

    return 0;
}

int target_clear(struct target *t)
{
    switch (t->type)
    {
    case TARGET_TYPE_NONE:
        return 0;

    case TARGET_TYPE_BIN:
        free(t->target);
        t->type = TARGET_TYPE_NONE;
        return 0;

    case TARGET_TYPE_INC:
    case TARGET_TYPE_LIB:
    case TARGET_TYPE_MAN:
    case TARGET_TYPE_SHR:
    case TARGET_TYPE_ETC:
    case TARGET_TYPE_SRC:
        t->type = TARGET_TYPE_NONE;
        return 1;
    }

    return 1;
}

int target_flush(struct target *t)
{
    switch (t->type)
    {
    case TARGET_TYPE_NONE:
        return 0;

    case TARGET_TYPE_BIN:
    case TARGET_TYPE_INC:
    case TARGET_TYPE_LIB:
    case TARGET_TYPE_MAN:
    case TARGET_TYPE_SHR:
    case TARGET_TYPE_ETC:
    case TARGET_TYPE_SRC:
        return 1;
    }

    return 1;
}

int target_set_bin(struct target *t, const char *target)
{
    assert(t->type == TARGET_TYPE_NONE);

    t->type = TARGET_TYPE_BIN;
    t->target = strdup(target);

    return 0;
}

int target_set_src(struct target *t, const char *source,
                   struct target *parent, const struct language_list *langs)
{
    assert(t->type == TARGET_TYPE_NONE);

    t->type = TARGET_TYPE_SRC;
    t->source = strdup(source);
    t->parent = parent;

    /* Attempts to find the language of this source */
    t->lang = language_list_search(langs, t->source);
    if (t->lang == NULL)
    {
        fprintf(stderr, "Could not find language for source '%s'\n",
                t->source);
        return 1;
    }

    printf("language: %s\n", t->lang->name);

    return 0;
}
