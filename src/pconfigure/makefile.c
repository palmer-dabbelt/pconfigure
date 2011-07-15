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
    fprintf(mf->file, ".SUFFIXES:\n");
}

void makefile_clear(struct makefile *mf)
{
    assert(mf != NULL);
    assert(mf->file != NULL);

    /* Writes out our list of all targets for the end */
    fprintf(mf->file, "dummy__all: ");
    string_list_fserialize(&(mf->targets_all), mf->file, " ");
    fprintf(mf->file, "\n\t\n\n");

    fclose(mf->file);
    mf->file = NULL;
}
