#include "language.h"

#include <stdlib.h>
#include <assert.h>
#include <stdio.h>

int language_init(struct language *lang)
{
    assert(lang != NULL);

    lang->name = NULL;

    lang->match = NULL;
    lang->adddeps = NULL;

    return 0;
}

int language_match(struct language *lang, const char *filename)
{
    assert(lang != NULL);

    /* All valid languages must have a match function */
    assert(lang->match != NULL);
    return lang->match(lang, filename);
}

int language_adddeps(struct language *lang, struct target *src,
                     struct makefile *mf)
{
    assert(lang != NULL);

    /* All valid languages must have an adddeps function */
    assert(lang->adddeps != NULL);
    return lang->adddeps(lang, src, mf);
}
