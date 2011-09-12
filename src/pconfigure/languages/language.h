#ifndef LANGUAGE_LANGUAGE_H
#define LANGUAGE_LANGUAGE_H

#include "../error.h"
#include "../target.h"

struct language;
struct target;

typedef struct language *(*language_func_search) (struct language * l,
                                                  struct target * t);
typedef enum error (*language_func_write) (struct language * l,
                                           struct target * t);

struct language
{
    /* The name of the language */
    char *name;

    /* The extension of source files of this language */
    char *extension;

    /* These are printed when operating */
    char *compile_str;
    char *link_str;

    /* These are used as commands when operating */
    char *compile_cmd;
    char *link_cmd;

    /* Lists of language-specific options */
    struct string_list *compile_opts;
    struct string_list *link_opts;

    /* A bunch of function pointers */
    language_func_search search;
    language_func_write write;
};

/* Initializes an empty language */
enum error language_init(struct language *l);
enum error language_clear(struct language *l);

#endif
