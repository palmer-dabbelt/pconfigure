
/*
 * Copyright (C) 2013 Palmer Dabbelt
 *   <palmer@dabbelt.com>
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

#include "funcs.h"
#include "str.h"

#include <pinclude.h>
#include <string.h>

struct func_printf
{
    void (*func) (void *, const char *, ...);
    void *arg;
};
static int printf_wrap_str(const char *format, void *args_uncast);

struct func_string
{
    void (*func) (void *, const char *);
    void *arg;
};
static int string_wrap_str(const char *s, void *args_uncast);

struct func_cmd
{
    bool type;
    const char *format;
    void (*func) (bool, const char *, ...);
    const char *skip_start;
};
static int cmd_wrap_str(const char *s, void *args_uncast);

struct func_Tcmd
{
    bool type;
    void (*func) (bool, const char *, ...);
};
static int cmd_wrap_Tstr(const char *s, void *args_uncast);

static bool str_ends(const char *haystack, const char *needle);

void func_pinclude_list_printf(const char *full_path,
                               void (*func) (void *, const char *, ...),
                               void *arg, char **dirs, char **defines)
{
    struct func_printf f;
    f.func = func;
    f.arg = arg;
    pinclude_list(full_path, &printf_wrap_str, &f, dirs, defines);
}

void func_pinclude_list_string(const char *full_path,
                               void (*func) (void *, const char *),
                               void *arg, char **dirs, char **defines)
{
    struct func_string f;
    f.func = func;
    f.arg = arg;
    pinclude_list(full_path, &string_wrap_str, &f, dirs, defines);
}

void func_stringlist_each_cmd_cont(struct stringlist *sl,
                                   void (*func) (bool, const char *, ...))
{
    struct func_cmd f;
    f.type = false;
    f.format = "\\ %s";
    f.func = func;
    f.skip_start = NULL;
    stringlist_each(sl, &cmd_wrap_str, &f);
}

void func_stringlist_each_cmd_lcont(struct stringlist *sl,
                                    void (*func) (bool, const char *, ...))
{
    struct func_cmd f;
    f.type = false;
    f.format = "\\ -l%s";
    f.func = func;
    f.skip_start = NULL;
    stringlist_each(sl, &cmd_wrap_str, &f);
}

void func_stringlist_each_cmd_Tcont(struct stringlist *sl,
                                    void (*func) (bool, const char *, ...))
{
    struct func_Tcmd f;
    f.type = false;
    f.func = func;
    stringlist_each(sl, &cmd_wrap_Tstr, &f);
}

void func_stringlist_each_cmd_cont_nostart(struct stringlist *sl,
                                           void (*func) (bool,
                                                         const char *,
                                                         ...),
                                           const char *skip)
{
    struct func_cmd f;
    f.type = false;
    f.format = "\\ %s";
    f.func = func;
    f.skip_start = skip;
    stringlist_each(sl, &cmd_wrap_str, &f);
}

int printf_wrap_str(const char *format, void *args_uncast)
{
    struct func_printf *args;
    args = args_uncast;
    args->func("%s", format);
    return 0;
}

int string_wrap_str(const char *s, void *args_uncast)
{
    struct func_string *args;
    args = args_uncast;
    args->func(args->arg, s);
    return 0;
}

int cmd_wrap_str(const char *s, void *args_uncast)
{
    struct func_cmd *args;
    args = args_uncast;

    if (str_sta(s, args->skip_start))
        return 0;

    args->func(args->type, args->format, s);
    return 0;
}

int cmd_wrap_Tstr(const char *s, void *args_uncast)
{
    struct func_Tcmd *args;
    args = args_uncast;

    if (str_ends(s, ".ld"))
        args->func(args->type, "\\ -T%s", s);
    else
        args->func(args->type, "\\ %s", s);

    return 0;
}

bool str_ends(const char *haystack, const char *needle)
{
    if (strlen(haystack) < strlen(needle))
        return false;

    return strcmp(haystack + strlen(haystack) - strlen(needle), needle) == 0;
}
