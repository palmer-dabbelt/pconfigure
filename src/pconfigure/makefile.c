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

    string_list_init(&(mf->targets_all));

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

    /* Writes out our list of all targets for the end */
    fprintf(mf->file, "dummy__all: ");
    string_list_fserialize(&(mf->targets_all), mf->file, " ");
    fprintf(mf->file, "\n\t\n\n");

    fclose(mf->file);
    mf->file = NULL;

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

    fprintf(mf->file, "%s:", tar);

    mf->state = MAKEFILE_STATE_DEPS;
}

void makefile_add_dep(struct makefile *mf, const char *dep)
{
    assert(mf != NULL);
    assert(dep != NULL);

    assert(mf->state == MAKEFILE_STATE_DEPS);
    assert(mf->file != NULL);

    fprintf(mf->file, " %s", dep);
}
