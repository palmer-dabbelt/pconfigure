#include "c.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <clang-c/Index.h>

#define FREE(x) {free(x); x = NULL;}

#define HASH_CODE_SIZE (strlen("__HASH_CODE__"))

static struct language_c *lang = NULL;

/* Functions that fill out the lang structure */
static struct language *l_search(struct language_c *l, struct target *t);
static enum error l_write(struct language_c *l, struct target *t);

/* Appends a hash string to the given string, like strcat */
static void hash_cat(char *out, struct target *t);

/* Adds all the dependencies of a given source file (by full path) to the given
   makefile. */
static void write_deps(CXFile included_file,
                       CXSourceLocation * inclusion_stack,
                       unsigned include_len, struct target *t);

enum error language_c_boot(void)
{
    enum error err;

    ASSERT_RETURN(lang == NULL, ERROR_ALREADY_BOOT);

    lang = malloc(sizeof(*lang));
    ASSERT_RETURN(lang != NULL, ERROR_MALLOC_NULL);

    err = language_init(&(lang->l));
    if (err != ERROR_NONE)
        return err;

    lang->l.name = strdup("c");
    lang->l.extension = strdup(".c");

    lang->l.compile_str = strdup("CC");
    lang->l.link_str = strdup("LD");
    lang->l.compile_cmd = strdup("gcc");
    lang->l.link_cmd = strdup("gcc");

    lang->l.search = (language_func_search) & l_search;
    lang->l.write = (language_func_write) & l_write;

    return ERROR_NONE;
}

enum error language_c_halt(void)
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

struct language *language_c_add(const char *name)
{
    if (strcmp(name, lang->l.name) == 0)
        return &(lang->l);

    return NULL;
}

/* These functions fill out the language struct */
struct language *l_search(struct language_c *l, struct target *t)
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

enum error l_write(struct language_c *l, struct target *t)
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
        FILE *mff;
        char *object_file;
        int object_file_size;
	struct string_list_node * cur;

	/* Discovers the actual target name, and the actual target binary dir */
        object_file_size = 0;
        object_file_size += strlen(t->bin_dir);
        object_file_size += strlen("/");
        object_file_size += strlen(t->passed_path);

        object_file = malloc(object_file_size);
        object_file[0] = '\0';
        strcat(object_file, t->bin_dir);
        strcat(object_file, "/");
        strcat(object_file, t->passed_path);

	/* Writes the list of dependencies of this target */
        err = makefile_create_target(t->makefile, object_file);
        if (err == ERROR_ALREADY_EXISTS)
        {
            FREE(object_file);
            return err;
        }

	/* Writes all the deps out */
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

        fprintf(mff, "\t@echo \"C%s\t%s\"\n", l->l.link_str,
                t->passed_path);
        fprintf(mff, "\t@mkdir -p \"%s\"\n", t->bin_dir);
        fprintf(mff, "\t@%s -o \"%s\"", l->l.link_cmd, t->full_path);
	
	cur = t->deps->head;
	while (cur != NULL)
	{
	    fprintf(mff, " \"%s\"", cur->data);
	    cur = cur->next;
	}
	fprintf(mff, "\n");

        makefile_end_cmds(t->makefile);

	/* Adds this to the list of all */
	string_list_add(t->makefile->targets_all, t->full_path);

        break;
    }
    case TARGET_TYPE_SOURCE:
    {
        char *object_file, *object_dir;
        int object_file_size;
        enum error err;
        int clang_argc;
        char **clang_argv;
        CXIndex index;
        CXTranslationUnit tu;
        FILE *mff;

	/* All sources must have a parent */
	ASSERT_RETURN(t->parent != NULL, ERROR_NULL_POINTER);
	ASSERT_RETURN(t->parent->deps != NULL, ERROR_NULL_POINTER);

        /* Generates the object file name */
        object_file_size = 0;
        object_file_size += strlen(t->obj_dir);
        object_file_size += strlen("/");
        object_file_size += strlen(t->passed_path);
        object_file_size += strlen("/");
        object_file_size += HASH_CODE_SIZE;
        object_file_size += 2;

        object_file = malloc(object_file_size);
        object_file[0] = '\0';
        strcat(object_file, t->obj_dir);
        strcat(object_file, "/");
        strcat(object_file, t->passed_path);
        strcat(object_file, "/");

        object_dir = strdup(object_file);

        hash_cat(object_file, t);
        strcat(object_file, ".o");

        /* Creates a target for this makefile */
        err = makefile_create_target(t->makefile, object_file);
        if (err == ERROR_ALREADY_EXISTS)
        {
            FREE(object_file);
            FREE(object_dir);
            return err;
        }

        /* Starts the list of dependencies */
        err = makefile_start_deps(t->makefile);

        /* FIXME: Pass all the compile-time arguments */
        clang_argc = 1;
        clang_argv = malloc(sizeof(*clang_argv) * (clang_argc + 1));
        clang_argv[0] = strdup(t->full_path);

        /* libclang initialization */
        index = clang_createIndex(0, 0);
        tu = clang_parseTranslationUnit(index, 0,
                                        (const char *const *)clang_argv,
                                        clang_argc, 0, 0,
                                        CXTranslationUnit_None);

        /* Writes every dependency out to the makefile */
        clang_getInclusions(tu, (CXInclusionVisitor) & write_deps, t);

        /* We're finished writing the list of dependencies */
        err = makefile_end_deps(t->makefile);

        /* Writes the list of commands used to build this project */
        makefile_start_cmds(t->makefile);
        mff = t->makefile->file;

        fprintf(mff, "\t@echo \"C%s\t%s\"\n", l->l.compile_str,
                t->passed_path);
        fprintf(mff, "\t@mkdir -p \"%s\"\n", object_dir);
        fprintf(mff, "\t@%s -c \"%s\" -o \"%s\"\n",
                l->l.compile_cmd, t->full_path, object_file);

        makefile_end_cmds(t->makefile);

	/* The parent (a binary) has another dependency */
	string_list_add(t->parent->deps, object_file);

        /* Cleans up all the allocated memory */
        FREE(object_file);
        FREE(object_dir);

        break;
    }
    }

    return ERROR_NONE;
}

static void hash_cat(char *out, struct target *t)
{
    strcat(out, "__HASH_CODE__");
}

static void write_deps(CXFile included_file,
                       CXSourceLocation * inclusion_stack,
                       unsigned include_len, struct target *t)
{
    CXString filename;
    const char *filename_cstr;

    filename = clang_getFileName(included_file);
    filename_cstr = clang_getCString(filename);

    /* Only write relative paths */
    if (filename_cstr[0] != '/')
        makefile_add_dep(t->makefile, filename_cstr);

    clang_disposeString(filename);
}
