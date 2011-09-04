#include "language.h"

#include <stdlib.h>
#include <assert.h>
#include <stdio.h>

int language_init(struct language *lang)
{
    assert(lang != NULL);

    lang->name = NULL;

    lang->clear = NULL;
    lang->match = NULL;
    lang->builddeps = NULL;
    lang->linkdeps = NULL;

    return 0;
}

int language_clear(struct language *lang)
{
    assert(lang != NULL);
    assert(lang->clear != NULL);
    return lang->clear(lang);
}

int language_match(struct language *lang, const char *filename)
{
    assert(lang != NULL);
    assert(lang->match != NULL);
    return lang->match(lang, filename);
}

int
language_builddeps(struct language *lang, struct target *src,
                   struct makefile *mf, struct context *c)
{
    assert(lang != NULL);
    assert(lang->builddeps != NULL);
    return lang->builddeps(lang, src, mf, c);
}

int
language_linkdeps(struct language *lang, struct target *src,
                  struct makefile *mf, struct context *c)
{
    assert(lang != NULL);
    assert(lang->linkdeps != NULL);
    return lang->linkdeps(lang, src, mf, c);
}
