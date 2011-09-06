#ifndef LANGUAGE_LANGUAGE_H
#define LANGUAGE_LANGUAGE_H

#include "../error.h"

struct language
{
    /* The name of the language */
    char * name;

    /* Lists of language-specific options */
    struct string_list * compile_opts;
    struct string_list * link_opts;
};

/* Initializes an empty language */
enum error language_init(struct language * l);

#endif
