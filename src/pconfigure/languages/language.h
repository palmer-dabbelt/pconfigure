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
typedef int (*language_func_builddeps_t) (struct language *, struct target *,
                                          struct makefile *,
                                          struct context *);
typedef int (*language_func_linkdeps_t) (struct language *, struct target *,
                                         struct makefile *, struct context *);

struct language
{
    char *name;
    char *compiler;
    char *linker;

    language_func_match_t match;
    language_func_builddeps_t builddeps;
    language_func_linkdeps_t linkdeps;
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
int language_builddeps(struct language *lang, struct target *src,
                       struct makefile *mf, struct context *c);

/*
 * Processes a single target (binary) file, and links all the objects requested
 * by that object file into the output
 */
int language_linkdeps(struct language *lang, struct target *bin,
                      struct makefile *mf, struct context *c);

#endif
