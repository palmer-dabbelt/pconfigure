#ifndef PCONFIGURE_MAKEFILE_H
#define PCONFIGURE_MAKEFILE_H

#include <stdio.h>
#include "string_list.h"

enum makefile_state
{
    MAKEFILE_STATE_INIT,
    MAKEFILE_STATE_CLEARED,
    MAKEFILE_STATE_DEPS
};

struct makefile
{
    enum makefile_state state;
    FILE *file;
    struct string_list targets_all;
};

void makefile_init(struct makefile *mf);
void makefile_clear(struct makefile *mf);

/* Adds a new target to the current makefile, sets the state to deps */
void makefile_add_target(struct makefile *mf, const char *tar);

/* Adds a new dependency to the curret target of a makefile */
void makefile_add_dep(struct makefile *mf, const char *dep);

#endif
