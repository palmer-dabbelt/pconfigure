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
    t->deps = NULL;
    t->lang = NULL;

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
        t->source = NULL;

        string_list_clear(t->deps);
        free(t->deps);
        t->deps = NULL;

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
        free(t->source);
        t->source = NULL;

        t->parent = NULL;
        t->lang = NULL;

        t->type = TARGET_TYPE_NONE;

        return 0;
    default:
        fprintf(stderr, "Unknown target type for target_clear()\n");
        t->type = TARGET_TYPE_NONE;
        return 1;
    }

    return 1;
}

int target_flush(struct target *t, struct makefile *mf, struct context *c)
{
    assert(t != NULL);

    switch (t->type)
    {
    case TARGET_TYPE_NONE:
        return 0;

    case TARGET_TYPE_BIN:
    {
        int err;

        c->target = t->parent;

        assert(t->lang != NULL);
        err = language_linkdeps(t->lang, t, mf, c);
        if (err != 0)
            return err;

        c->target = t->parent;

        return 0;
    }
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
    {
        int err;

        assert(t->lang != NULL);
        err = language_builddeps(t->lang, t, mf, c);
        if (err != 0)
            return err;

        c->target = t->parent;

        return 0;
    }
    default:
        fprintf(stderr, "Unknown target type for targt_flush()\n");
        return 1;
    }

    return 1;
}

int target_set_bin(struct target *t, const char *target, struct context *c)
{
    assert(t->type == TARGET_TYPE_NONE);

    t->type = TARGET_TYPE_BIN;
    t->target = malloc(strlen(target) + strlen(c->bin_dir) + strlen("/") + 1);
    assert(t->target != NULL);
    t->target[0] = '\0';
    strcat(t->target, c->bin_dir);
    strcat(t->target, "/");
    strcat(t->target, target);

    t->deps = malloc(sizeof(*t->deps));
    assert(t->deps != NULL);
    string_list_init(t->deps);

    return 0;
}

int target_set_src(struct target *t, const char *source,
                   struct target *parent, struct context *c)
{
    assert(t->type == TARGET_TYPE_NONE);

    t->type = TARGET_TYPE_SRC;

    t->source = malloc(strlen(source) + strlen(c->src_dir) + strlen("/") + 1);
    assert(t->source != NULL);
    t->source[0] = '\0';
    strcat(t->source, c->src_dir);
    strcat(t->source, "/");
    strcat(t->source, source);

    t->parent = parent;

    /* Attempts to find the language of this source */
    t->lang = language_list_search(c->languages, t->source);
    if (t->lang == NULL)
    {
        fprintf(stderr, "Could not find language for source '%s'\n",
                t->source);
        return 1;
    }

    return 0;
}

int target_set_src_fullname(struct target *t, const char *source,
                            struct target *parent, struct context *c)
{
    assert(t->type == TARGET_TYPE_NONE);

    t->type = TARGET_TYPE_SRC;

    t->source = strdup(source);
    t->parent = parent;

    /* Attempts to find the language of this source */
    t->lang = language_list_search(c->languages, t->source);
    if (t->lang == NULL)
    {
        fprintf(stderr, "Could not find language for source '%s'\n",
                t->source);
        return 1;
    }

    return 0;
}
