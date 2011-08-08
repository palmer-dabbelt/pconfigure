#ifndef PCONFIGURE_MAKEFILE_H
#define PCONFIGURE_MAKEFILE_H

#include <stdio.h>
#include "string_list.h"

enum makefile_state
{
    MAKEFILE_STATE_INIT,
    MAKEFILE_STATE_CLEARED,
    MAKEFILE_STATE_DEPS,
    MAKEFILE_STATE_CMDS,
    MAKEFILE_STATE_CMD_WRITE
};

struct makefile
{
    enum makefile_state state;
    FILE *file;
    struct string_list *targets;
};

void makefile_init(struct makefile *mf);
void makefile_clear(struct makefile *mf);

/* Adds a new target to the current makefile, sets the state to deps */
void makefile_add_target(struct makefile *mf, const char *tar);

/* Adds a new dependency to the curret target of a makefile */
void makefile_add_dep(struct makefile *mf, const char *dep);

/* Ends the list of dependencies of the current file */
void makefile_end_deps(struct makefile *mf);

/* Starts (or ends) writing a command */
void makefile_start_cmd(struct makefile *mf);
void makefile_end_cmd(struct makefile *mf);

/* Returns an FD that can be used to write to a command to the file.  There is
   no need to close the FD, just make sure not to use it after you call
   end_cmd. */
FILE *makefile_cmd_fd(struct makefile *mf);

#endif
