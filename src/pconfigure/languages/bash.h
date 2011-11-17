#ifndef LANGUAGES_BASH_H
#define LANGUAGES_BASH_H

#include "language.h"
#include "../target.h"

struct language_bash
{
    /* This is a subclass of language, all other definitions must be after
     * this line */
    struct language l;

};

/* Initializes the C language */
enum error language_bash_boot(void);
enum error language_bash_halt(void);

/* Returns a pointer to the (static) C language, if the name matches */
struct language *language_bash_add(const char *name);

#endif
