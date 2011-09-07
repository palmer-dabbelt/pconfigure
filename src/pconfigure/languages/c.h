#ifndef LANGUAGES_C_H
#define LANGUAGES_C_H

#include "language.h"

struct language_c
{
    /* This is a subclass of language, all other definitions must be after
       this line */
    struct language l;

    
};

/* Initializes the C language */
enum error language_c_boot(void);
enum error language_c_halt(void);

/* Returns NULL if the given language is C, otherwise returns the C language */
struct language * language_c_add(const char * name);

#endif
