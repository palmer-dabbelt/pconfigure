#include "c.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Polymorphic functions */
static int lf_match(struct language *lang, const char *filename)
{
    printf("Language: '%s'\tComparison: '%s'\n", lang->name, filename);

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

    return (struct language *)out;
}
