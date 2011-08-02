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
        return 1;
    case TARGET_TYPE_LIB:
        return 1;
    case TARGET_TYPE_MAN:
        return 1;
    case TARGET_TYPE_SHR:
        return 1;
    case TARGET_TYPE_ETC:
        return 1;
    case TARGET_TYPE_SRC:
    default:
        fprintf(stderr, "Unknown target type for target_clear()\n");
        t->type = TARGET_TYPE_NONE;
        return 1;
    }

    return 1;
}

int target_flush(struct target *t, struct makefile *mf)
{
    if (t == NULL)
        return 1;

    switch (t->type)
    {
    case TARGET_TYPE_NONE:
        return 0;

    case TARGET_TYPE_SRC:
    {
        int err;

        assert(t->lang != NULL);
        err = language_adddeps(t->lang, t, mf);
        if (err != 0)
            return err;

        return 0;
    }

    case TARGET_TYPE_BIN:
        return 1;
    case TARGET_TYPE_INC:
        return 1;
    case TARGET_TYPE_LIB:
        return 1;
    case TARGET_TYPE_MAN:
        return 1;
    case TARGET_TYPE_SHR:
        return 1;
    case TARGET_TYPE_ETC:
        return 1;
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

    return 0;
}
