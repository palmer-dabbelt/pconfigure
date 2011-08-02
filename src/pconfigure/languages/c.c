#include "c.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

/* Polymorphic functions */
static int lf_match(struct language *lang, const char *filename)
{
    return 1;
}

static int lf_adddeps(struct language *lang, struct target *src,
                      struct makefile *mf)
{
    assert(lang != NULL);
    assert(src != NULL);
    assert(mf != NULL);

    printf("lf_adddps not implemented for C\n");
    return 1;
}

struct language *language_c_boot(void)
{
    struct language_c *out;

    out = malloc(sizeof(*out));
    if (out == NULL)
        return NULL;
    language_init((struct language *)out);

    /* TODO: change this to "c", here for compatibility */
    out->lang.name = strdup("gcc");

    out->lang.match = &lf_match;
    out->lang.adddeps = &lf_adddeps;

    return (struct language *)out;
}
