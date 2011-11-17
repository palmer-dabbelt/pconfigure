#include "bash.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <assert.h>

#define FREE(x) {free(x); x = NULL;}

static struct language_bash *lang = NULL;

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

    lang->l.compile_str = strdup("BASHC");
    lang->l.link_str = strdup("BASHC");
    lang->l.compile_cmd = strdup("pbashc");
    lang->l.link_cmd = strdup("pbashld");

#if 0
    lang->l.search = (language_func_search) & l_search;
    lang->l.write = (language_func_write) & l_write;
#else
    lang->l.search = NULL;
    lang->l.write = NULL;
#endif

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
