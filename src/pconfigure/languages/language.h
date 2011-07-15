#ifndef PCONFIGURE_LANGUAGE_H
#define PCONFIGURE_LANGUAGE_H

struct language;

/* Types of function pointers inside a language object -- for polymorphism */
typedef int (*language_func_match_t) (struct language *, const char *);

struct language
{
    char *name;

    language_func_match_t match;
};

/* Ensures that all fields get properly initialized */
int language_init(struct language *lang);

/* Helper functions for the polymorphism */
int language_match(struct language *lang, const char *filename);

#endif
