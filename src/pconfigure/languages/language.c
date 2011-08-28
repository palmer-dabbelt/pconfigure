#include "language.h"

#include <stdlib.h>
#include <assert.h>
#include <stdio.h>

int language_init(struct language *lang)
{
    assert(lang != NULL);

    lang->name = NULL;

    lang->match = NULL;
    lang->builddeps = NULL;
    lang->linkdeps = NULL;

    return 0;
}

int language_match(struct language *lang, const char *filename)
{
    assert(lang != NULL);

    /* All valid languages must have a match function */
    assert(lang->match != NULL);
    return lang->match(lang, filename);
}

int language_builddeps(struct language *lang, struct target *src,
                       struct makefile *mf, struct context *c)
{
    assert(lang != NULL);

    /* All valid languages must have an builddeps function */
    assert(lang->builddeps != NULL);
    return lang->builddeps(lang, src, mf, c);
}

int language_linkdeps(struct language *lang, struct target *src,
                      struct makefile *mf, struct context *c)
{
    assert(lang != NULL);

    /* All valid languages must have a linkdeps function */
    assert(lang->linkdeps != NULL);
    return lang->linkdeps(lang, src, mf, c);
}
