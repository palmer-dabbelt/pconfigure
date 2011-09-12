#include "makefile.h"

#include "defaults.h"
#include <stdlib.h>

#define FREE(x) {free(x); x = NULL;}

enum error makefile_boot(void)
{
    return ERROR_NONE;
}

enum error makefile_init(struct makefile *m)
{
    enum error err;

    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);

    /* There is a bit of state associated with makefiles */
    m->state = MAKEFILE_STATE_NONE;

    m->file = fopen(DEFAULT_OUTFILE, "w");
    ASSERT_RETURN(m->file != NULL, ERROR_FILE_NOT_FOUND);

    m->targets_all = malloc(sizeof(*(m->targets_all)));
    if (m->targets_all == NULL)
    {
        fclose(m->file);
        return ERROR_MALLOC_NULL;
    }
    m->build_list = malloc(sizeof(*(m->build_list)));
    if (m->build_list == NULL)
    {
        fclose(m->file);
        free(m->targets_all);
        return ERROR_MALLOC_NULL;
    }

    err = string_list_init(m->targets_all);
    if (err != ERROR_NONE)
    {
        fclose(m->file);
        FREE(m->targets_all);
        FREE(m->build_list);
        return err;
    }

    err = string_list_init(m->build_list);
    if (err != ERROR_NONE)
    {
        fclose(m->file);
        string_list_clear(m->targets_all);
        FREE(m->targets_all);
        FREE(m->build_list);
        return err;
    }

    /* Makefiles require a prelude */
    fprintf(m->file, "SHELL=/bin/bash\n\nall: __pconfigure_all\n\n");

    return ERROR_NONE;
}

enum error makefile_clear(struct makefile *m)
{
    enum error err;

    fprintf(m->file, "__pconfigure_all:\n\n");
    fclose(m->file);
    m->file = NULL;

    err = string_list_clear(m->targets_all);
    if (err != ERROR_NONE)
        return err;
    FREE(m->targets_all);

    return ERROR_NONE;
}

enum error makefile_create_target(struct makefile *m, const char *name)
{
    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_NONE, ERROR_INTERNAL_STATE);

    fprintf(m->file, "%s:", name);
    m->state = MAKEFILE_STATE_TARGET;

    return ERROR_NONE;
}

enum error makefile_start_deps(struct makefile *m)
{
    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_TARGET, ERROR_INTERNAL_STATE);

    m->state = MAKEFILE_STATE_DEPS;

    return ERROR_NONE;
}

enum error makefile_add_dep(struct makefile *m, const char *dep)
{
    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_DEPS, ERROR_INTERNAL_STATE);

    fprintf(m->file, " %s", dep);

    return ERROR_NONE;
}

enum error makefile_end_deps(struct makefile *m)
{
    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_DEPS, ERROR_INTERNAL_STATE);

    fprintf(m->file, "\n");
    m->state = MAKEFILE_STATE_DEPS_DONE;

    return ERROR_NONE;
}

enum error makefile_start_cmds(struct makefile *m)
{
    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_DEPS_DONE, ERROR_INTERNAL_STATE);

    m->state = MAKEFILE_STATE_CMDS;

    return ERROR_NONE;
}

enum error makefile_add_cmd(struct makefile *m, const char *cmd)
{
    RETURN_UNIMPLEMENTED;
}

enum error makefile_end_cmds(struct makefile *m)
{
    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_CMDS, ERROR_INTERNAL_STATE);

    fprintf(m->file, "\n");
    m->state = MAKEFILE_STATE_NONE;

    return ERROR_NONE;
}
