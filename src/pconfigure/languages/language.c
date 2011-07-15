#include "language.h"

#include <stdlib.h>
#include <assert.h>

int language_init(struct language *lang)
{
    if (lang == NULL)
        return 1;

    lang->name = NULL;
    lang->match = NULL;

    return 0;
}

int language_match(struct language *lang, const char *filename)
{
    if (lang == NULL)
        return 0;

    /* All valid languages must have a match function */
    assert(lang->match != NULL);
    return lang->match(lang, filename);
}
