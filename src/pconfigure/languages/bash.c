#include "bash.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <assert.h>

#define FREE(x) {free(x); x = NULL;}

static struct language_bash *lang = NULL;

/* Functions that fill out the lang structure */
static struct language *l_search(struct language_bash *l, struct target *t);
static enum error l_write(struct language_bash *l, struct target *t);

enum error language_bash_boot(void)
{
    enum error err;

    ASSERT_RETURN(lang == NULL, ERROR_ALREADY_BOOT);

    lang = malloc(sizeof(*lang));
    ASSERT_RETURN(lang != NULL, ERROR_MALLOC_NULL);

    err = language_init(&(lang->l));
    if (err != ERROR_NONE)
        return err;

    lang->l.name = strdup("bash");
    lang->l.extension = strdup(".bash");

    lang->l.compile_str = strdup("ShouldNotSeeThis");
    lang->l.link_str = strdup("BASHC");
    lang->l.compile_cmd = strdup("ShouldNotRunThis");
    lang->l.link_cmd = strdup("pbashc");

    lang->l.search = (language_func_search) & l_search;
    lang->l.write = (language_func_write) & l_write;

    return ERROR_NONE;
}

enum error language_bash_halt(void)
{
    enum error err;

    FREE(lang->l.name);
    FREE(lang->l.extension);
    FREE(lang->l.compile_str);
    FREE(lang->l.link_str);
    FREE(lang->l.compile_cmd);
    FREE(lang->l.link_cmd);

    err = language_clear(&(lang->l));
    if (err != ERROR_NONE)
        return err;

    FREE(lang);

    return ERROR_NONE;
}

struct language *language_bash_add(const char *name)
{
    if (strcmp(name, lang->l.name) == 0)
        return &(lang->l);

    return NULL;
}

enum error l_write(struct language_bash *l, struct target *t)
{
    enum error err;

    err = ERROR_NONE;

    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);
    ASSERT_RETURN(t != NULL, ERROR_NULL_POINTER);

    /* Writes the source target out to the makefile */
    ASSERT_RETURN(t->makefile != NULL, ERROR_NULL_POINTER);

    switch (t->type)
    {
    case TARGET_TYPE_NONE:
        break;
    case TARGET_TYPE_BINARY:
    {
        struct string_list_node *cur;
        FILE *mff;

        err = makefile_create_target(t->makefile, t->full_path);

        makefile_start_deps(t->makefile);

        cur = t->deps->head;
        while (cur != NULL)
        {
            makefile_add_dep(t->makefile, cur->data);
            cur = cur->next;
        }
        makefile_end_deps(t->makefile);

        /* Writes the list of commands used to build this binary */
        makefile_start_cmds(t->makefile);
        mff = t->makefile->file;

        fprintf(mff, "\t@echo \"%s\t%s\"\n", l->l.link_str, t->passed_path);
        fprintf(mff, "\t@mkdir -p \"%s\"\n", t->bin_dir);
        fprintf(mff, "\t@%s -o \"%s\"", l->l.link_cmd, t->full_path);

        cur = t->deps->head;
        while (cur != NULL)
        {
            fprintf(mff, " \"%s\"", cur->data);
            cur = cur->next;
        }

        cur = t->language->link_opts->head;
        while (cur != NULL)
        {
            fprintf(mff, " %s", cur->data);
            cur = cur->next;
        }
        cur = t->link_opts->head;
        while (cur != NULL)
        {
            fprintf(mff, " %s", cur->data);
            cur = cur->next;
        }

        fprintf(mff, "\n");

        makefile_end_cmds(t->makefile);

        /* Adds this to the list of all */
        string_list_add(t->makefile->targets_all, t->full_path);

        break;
    }
    case TARGET_TYPE_SOURCE:
        /* The parent (a binary) has another dependency */
        string_list_add(t->parent->deps, t->full_path);

        break;
    }

    return ERROR_NONE;
}

struct language *l_search(struct language_bash *l, struct target *t)
{
    ASSERT_RETURN(t->full_path != NULL, NULL);
    ASSERT_RETURN(t->parent != NULL, NULL);

    if (t->parent->language != NULL)
        if (strcmp(t->parent->language->name, l->l.name) != 0)
            return NULL;

    if (strcmp(t->full_path + strlen(t->full_path) - strlen(l->l.extension),
               l->l.extension) == 0)
    {
        t->parent->language = (struct language *)l;
        return (struct language *)l;
    }

    return NULL;
}
