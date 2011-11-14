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
    ASSERT_RETURN(m->targets_all != NULL, ERROR_MALLOC_NULL);
    err = string_list_init(m->targets_all);
    CHECK_ERROR(err);

    m->build_list = malloc(sizeof(*(m->build_list)));
    ASSERT_RETURN(m->build_list != NULL, ERROR_MALLOC_NULL);
    err = string_list_init(m->build_list);
    CHECK_ERROR(err);

    m->install = malloc(sizeof(*(m->install)));
    ASSERT_RETURN(m->install != NULL, ERROR_MALLOC_NULL);
    err = string_list_init(m->install);
    CHECK_ERROR(err);

    /* Makefiles require a prelude */
    fprintf(m->file, "SHELL=/bin/bash\n\nall: __pconfigure_all\n\n");

    /* These targets are phony */
    fprintf(m->file,
	    ".PHONY: distclean clean all install __pconfigure_all"
	    "\n\n");

    return ERROR_NONE;
}

enum error makefile_clear(struct makefile *m)
{
    enum error err;
    struct string_list_node *cur;

    fprintf(m->file, "__pconfigure_all:");
    cur = m->targets_all->head;
    while (cur != NULL)
    {
        fprintf(m->file, " %s", cur->data);
        cur = cur->next;
    }
    fprintf(m->file, "\n\n");

    fprintf(m->file, "clean:\n");
    cur = m->build_list->head;
    while (cur != NULL)
    {
        fprintf(m->file, "\t@rm \"%s\" >& /dev/null || true\n", cur->data);
        cur = cur->next;
    }
    fprintf(m->file, "\n");

    fprintf(m->file, "distclean: clean\n\t@rm \"%s\"\n\t@pclean\n\n",
	    DEFAULT_OUTFILE);

    fprintf(m->file, "install: all\n");
    cur = m->install->head;
    while (cur != NULL)
    {
	fprintf(m->file, "\t@echo \"INS\t\"%s\n", cur->data);
	fprintf(m->file, "\t@install %s\n", cur->data);
	cur = cur->next;
    }

    fclose(m->file);
    m->file = NULL;

    err = string_list_clear(m->targets_all);
    CHECK_ERROR(err);
    FREE(m->targets_all);

    err = string_list_clear(m->build_list);
    CHECK_ERROR(err);
    FREE(m->build_list);

    return ERROR_NONE;
}

enum error makefile_create_target(struct makefile *m, const char *name)
{
    enum error err;

    ASSERT_RETURN(m != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->file != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(m->state == MAKEFILE_STATE_NONE, ERROR_INTERNAL_STATE);

    err = string_list_include(m->build_list, name);
    if (err != ERROR_NONE)
        return err;

    err = string_list_add(m->build_list, name);
    CHECK_ERROR(err);

    fprintf(m->file, "%s: %s", name, DEFAULT_OUTFILE);
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
