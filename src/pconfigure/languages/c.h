#ifndef LANGUAGES_C_H
#define LANGUAGES_C_H

#include "language.h"
#include "../target.h"

struct language_c
{
    /* This is a subclass of language, all other definitions must be after
       this line */
    struct language l;

    
};

/* Initializes the C language */
enum error language_c_boot(void);
enum error language_c_halt(void);

/* Returns a pointer to the (static) C language, if the name matches */
struct language * language_c_add(const char * name);

#endif
