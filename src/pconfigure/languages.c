
/*
 * Copyright (C) 2011 Daniel Dabbelt
 *   <palmem@comcast.net>
 *
 * This file is part of pconfigure.
 * 
 * pconfigure is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * pconfigure is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with pconfigure.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "languages.h"

#include <stdio.h>
#include <stdlib.h>

#include "languages/c.h"
#include "languages/bash.h"

#define FREE(x) {free(x); x = NULL;}

/* The last language to be added, used for COMPILEOPTS */
static struct language *last_added;

/* A list of all the languages in the system, used to search for which ones
   should be used to compile */
struct language_list
{
    struct language_list *next;
    struct language *lang;
};
static struct language_list *list;

enum error languages_boot(void)
{
    enum error err;

    err = language_c_boot();
    if (err != ERROR_NONE)
        return err;

    err = language_bash_boot();
    if (err != ERROR_NONE)
        return err;

    last_added = NULL;
    list = NULL;

    return ERROR_NONE;
}

enum error languages_halt(void)
{
    enum error err;
    struct language_list *cur;

    cur = list;
    while (cur != NULL)
    {
        struct language_list *next;

        next = cur->next;
        FREE(cur);
        cur = next;
    }

    err = language_c_halt();
    if (err != ERROR_NONE)
        return err;

    err = language_bash_halt();
    if (err != ERROR_NONE)
        return err;

    return ERROR_NONE;
}

enum error languages_add(const char *name)
{
    struct language *ret, *ret_good;

    /* Searches for a language that can match this languages' name */
    ret_good = NULL;

    ret = language_c_add(name);
    if (ret != NULL)
        ret_good = ret;

    ret = language_bash_add(name);
    if (ret != NULL)
        ret_good = ret;

    /* If a language was found, add it to the list */
    if (ret_good != NULL)
    {
        struct language_list *new;

        last_added = ret_good;

        new = malloc(sizeof(*new));
        ASSERT_RETURN(new != NULL, ERROR_MALLOC_NULL);
        new->next = list;
        new->lang = last_added;
        list = new;

        return ERROR_NONE;
    }

    fprintf(stderr, "Language '%s' does not exist\n", name);
    return ERROR_FILE_NOT_FOUND;
}

struct language *languages_last_added(void)
{
    return last_added;
}

struct language *languages_search(struct target *t)
{
    struct language_list *cur;

    cur = list;
    while (cur != NULL)
    {
        struct language *ret;

        ret = cur->lang->search(cur->lang, t);
        if (ret != NULL)
            return ret;

        cur = cur->next;
    }

    return NULL;
}
