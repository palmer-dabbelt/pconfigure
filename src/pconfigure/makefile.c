#include "makefile.h"

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

void makefile_init(struct makefile *mf)
{
    assert(mf != NULL);

    mf->file = fopen("Makefile-c", "w");
    if (mf->file == NULL)
        return;

    mf->targets = malloc(sizeof(*(mf->targets)));
    assert(mf->targets != NULL);
    string_list_init(mf->targets);

    /* Make sure to use bash as our shell */
    fprintf(mf->file, "SHELL=/bin/bash\n\n");

    /* Write a dummy "all" target, we will actually write this later but it is
     * expected to be the first target in the list */
    fprintf(mf->file, "all: dummy__all\n\t\n\n");

    /* Disables all suffixes to prevent any trouble */
    fprintf(mf->file, ".SUFFIXES:\n\t\n\n");

    /* The makefile has been initialized */
    mf->state = MAKEFILE_STATE_INIT;
}

void makefile_clear(struct makefile *mf)
{
    assert(mf != NULL);
    assert(mf->file != NULL);

    /* There may be leftover things, make sure they're gone */
    if (mf->state == MAKEFILE_STATE_DEPS)
        fprintf(mf->file, "\n\t\n\n");
    if (mf->state == MAKEFILE_STATE_CMDS)
        fprintf(mf->file, "\n");

    /* Writes out our list of all targets for the end */
    fprintf(mf->file, "dummy__all: ");
    string_list_fserialize(mf->targets, mf->file, " ");
    fprintf(mf->file, "\n\t\n\n");

    fclose(mf->file);
    mf->file = NULL;

    /* Empty the list of targets, and unallocate it */
    string_list_clear(mf->targets);
    free(mf->targets);
    mf->targets = NULL;

    /* The makefile has been cleared */
    mf->state = MAKEFILE_STATE_CLEARED;
}

void makefile_add_target(struct makefile *mf, const char *tar)
{
    assert(mf != NULL);
    assert(tar != NULL);

    assert(mf->state != MAKEFILE_STATE_DEPS);
    assert(mf->state != MAKEFILE_STATE_CLEARED);
    assert(mf->file != NULL);

    if (mf->state == MAKEFILE_STATE_CMDS)
        fprintf(mf->file, "\n");

    fprintf(mf->file, "%s: ", tar);

    mf->state = MAKEFILE_STATE_TARGET;
}

void makefile_add_dep(struct makefile *mf, const char *dep)
{
    assert(mf != NULL);
    assert(dep != NULL);

    assert(mf->state == MAKEFILE_STATE_DEPS ||
           mf->state == MAKEFILE_STATE_FIRSTDEP);
    assert(mf->file != NULL);

    if (mf->state == MAKEFILE_STATE_FIRSTDEP)
        fprintf(mf->file, "%s", dep);
    else
        fprintf(mf->file, " %s", dep);

    mf->state = MAKEFILE_STATE_DEPS;
}

void makefile_start_deps(struct makefile *mf)
{
    assert(mf != NULL);
    assert(mf->state == MAKEFILE_STATE_TARGET);
    assert(mf->file != NULL);

    mf->state = MAKEFILE_STATE_FIRSTDEP;
}

void makefile_end_deps(struct makefile *mf)
{
    assert(mf != NULL);

    assert(mf->state == MAKEFILE_STATE_DEPS);
    assert(mf->file != NULL);

    fprintf(mf->file, "\n");

    mf->state = MAKEFILE_STATE_CMDS;
}

FILE *makefile_dep_fd(struct makefile *mf)
{
    assert(mf != NULL);

    assert(mf->state == MAKEFILE_STATE_DEPS ||
           mf->state == MAKEFILE_STATE_FIRSTDEP);
    assert(mf->file != NULL);

    if (mf->state == MAKEFILE_STATE_FIRSTDEP)
        mf->state = MAKEFILE_STATE_DEPS;
    return mf->file;
}

void makefile_start_cmd(struct makefile *mf)
{
    assert(mf != NULL);

    assert(mf->state == MAKEFILE_STATE_CMDS);
    assert(mf->file != NULL);

    fprintf(mf->file, "\t");

    mf->state = MAKEFILE_STATE_CMD_WRITE;
}

void makefile_end_cmd(struct makefile *mf)
{
    assert(mf != NULL);

    assert(mf->state == MAKEFILE_STATE_CMD_WRITE);
    assert(mf->file != NULL);

    fprintf(mf->file, "\n");

    mf->state = MAKEFILE_STATE_CMDS;
}

FILE *makefile_cmd_fd(struct makefile *mf)
{
    assert(mf != NULL);

    assert(mf->state == MAKEFILE_STATE_CMD_WRITE);
    assert(mf->file != NULL);

    return mf->file;
}
