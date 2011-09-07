#ifndef LANGUAGES_H
#define LANGUAGES_H

#include "error.h"
#include "languages/language.h"

/* Initializes the languages module */
enum error languages_boot(void);
enum error languages_halt(void);

/* Adds a single language to the list of currently availiable languages */
enum error languages_add(const char *name);

/* Returns the last language added, or NULL if no languages have been added */
struct language * languages_last_added(void);

#endif
