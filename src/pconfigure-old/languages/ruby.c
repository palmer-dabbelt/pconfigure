#include "ruby.h"

#include <stdlib.h>
#include <string.h>

/* Polymorphic functions */
static int lf_match(struct language *lang, const char *filename)
{
    return 0;
}

struct language *language_ruby_boot(void)
{
    struct language_ruby *out;

    out = malloc(sizeof(*out));
    if (out == NULL)
        return NULL;
    language_init((struct language *)out);

    out->lang.name = strdup("ruby");

    out->lang.match = &lf_match;

    return (struct language *)out;
}
