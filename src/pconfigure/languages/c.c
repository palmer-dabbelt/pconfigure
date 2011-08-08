#include "c.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

#include <clang-c/Index.h>

/* Helper functions (not specific to one of the functions below) */
static char *source2object(const char *source, struct context *c)
{
    char *object;
    const char *cur;            /* The character to process, in the input */
    char *dot;                  /* The last dot seen */
    char *dest;                 /* The current place to write to in the output */
    char *start;                /* Make sure not to backup past here */
    int count;

    object = malloc(strlen(c->obj_dir) + strlen(source) * 2 + 1);
    assert(object != NULL);
    object[0] = '\0';

    strcat(object, c->obj_dir);
    start = object + strlen(object);

    /* Filters ..'s out, and converts /'s into __'s */
    count = 0;
    dest = start;
    dot = NULL;
    for (cur = source; *cur != '\0'; cur++)
    {
        /* dot will always point to the last dot seen, for replacing the end */
        if (*cur == '.')
            dot = dest;

        *dest = *cur;
        dest++;
        *dest = '\0';
    }

    printf("object: '%s'\n", object);

    /* Should have made sure this is a .c file, so there must be a dot in it
     * somewhere */
    assert(dot != NULL);

    return object;
}

/* Polymorphic functions */
static int lf_match(struct language *lang, const char *filename)
{
    return 1;
}

/* This helper writes every included file out to the makefile as a dependency */
struct adddeps_help_iv_mfputs_cd
{
    struct makefile *mf;
};
static void lf_adddeps_help_iv_mfputs(CXFile included_file,
                                      CXSourceLocation * inclusion_stack,
                                      unsigned include_len,
                                      CXClientData client_data)
{
    CXString filename;
    const char *filename_cstr;
    struct adddeps_help_iv_mfputs_cd *args;

    args = (struct adddeps_help_iv_mfputs_cd *)client_data;
    assert(args != NULL);

    filename = clang_getFileName(included_file);

    filename_cstr = clang_getCString(filename);
    makefile_add_dep(args->mf, filename_cstr);
    clang_disposeString(filename);
    filename_cstr = NULL;
}

static int lf_adddeps(struct language *lang, struct target *src,
                      struct makefile *mf, struct context *c)
{
    int clang_argc;
    char **clang_argv;
    CXIndex index;
    CXTranslationUnit tu;
    struct adddeps_help_iv_mfputs_cd mfputs_args;
    const char *objfile;

    assert(lang != NULL);
    assert(src != NULL);
    assert(mf != NULL);

    printf("clang parsing '%s'\n", src->source);

    objfile = source2object(src->source, c);
    makefile_add_target(mf, objfile);

    /* TODO: make libclang listen to all the compileopts, not just the 
     * filename of the input file */
    clang_argc = 1;
    clang_argv = malloc(sizeof(char *));
    assert(clang_argv != NULL);
    clang_argv[0] = strdup(src->source);

    /* Starts at the beginning of the input file, and checks every included
     * file for matches */
    index = clang_createIndex(0, 0);
    tu = clang_parseTranslationUnit(index, 0, (const char *const *)clang_argv,
                                    clang_argc, 0, 0, CXTranslationUnit_None);

    /* This actually does the calls, note that in uses a helper function */
    mfputs_args.mf = mf;
    clang_getInclusions(tu, &lf_adddeps_help_iv_mfputs, &mfputs_args);

    /* Cleanup code for libclang */
    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(index);

    free(clang_argv[0]);
    free(clang_argv);

    return 0;
}

struct language *language_c_boot(void)
{
    struct language_c *out;

    out = malloc(sizeof(*out));
    if (out == NULL)
        return NULL;
    language_init((struct language *)out);

    /* TODO: change this to "c", here for compatibility */
    out->lang.name = strdup("gcc");

    out->lang.match = &lf_match;
    out->lang.adddeps = &lf_adddeps;

    return (struct language *)out;
}
