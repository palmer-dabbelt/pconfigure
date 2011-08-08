#ifndef PCONFIGURE_LANGUAGE_H
#define PCONFIGURE_LANGUAGE_H

/* TODO: Fix the backwards dependency */
#include "../target.h"
#include "../makefile.h"
#include "../context.h"

struct language;

/*
 * Types of function pointers inside a language object -- for polymorphism.
 *   Documentation for each method is availiable in their corresponding
 *   function below
 */
typedef int (*language_func_match_t) (struct language *, const char *);
typedef int (*language_func_adddeps_t) (struct language *, struct target *,
                                        struct makefile *, struct context *);

struct language
{
    char *name;

    language_func_match_t match;
    language_func_adddeps_t adddeps;
};

/* Ensures that all fields get properly initialized */
int language_init(struct language *lang);

/* Returns 1 if the given file can be parsed by the given language, otherwise
   returns 0 */
int language_match(struct language *lang, const char *filename);

/*
 * Processes a single source file (given as the target argument).  Adds all
 * files referenced by this file to the parent, and creates new targets for
 * them in the given Makefile
 */
int language_adddeps(struct language *lang, struct target *src,
                     struct makefile *mf, struct context *c);

#endif
