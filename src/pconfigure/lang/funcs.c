
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

#include <pinclude.h>

struct func_printf
{
    void (*func) (const char *, ...);
};
static int printf_wrap_str(const char *format, void *args_uncast);

struct func_string
{
    void (*func) (const char *);
};
static int string_wrap_str(const char *s, void *args_uncast);

struct func_cmd
{
    bool type;
    const char *format;
    void (*func) (bool, const char *, ...);
};
static int cmd_wrap_str(const char *s, void *args_uncast);

void func_pinclude_list_printf(const char *full_path,
                               void (*func) (const char *, ...), char **dirs)
{
    struct func_printf f;
    f.func = func;
    pinclude_list(full_path, &printf_wrap_str, &f, dirs);
}

void func_pinclude_list_string(const char *full_path,
                               void (*func) (const char *), char **dirs)
{
    struct func_string f;
    f.func = func;
    pinclude_list(full_path, &string_wrap_str, &f, dirs);
}

void func_stringlist_each_cmd_cont(struct stringlist *sl,
                                   void (*func) (bool, const char *, ...))
{
    struct func_cmd f;
    f.type = false;
    f.format = "\\ %s";
    f.func = func;
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
    args->func(s);
    return 0;
}

int cmd_wrap_str(const char *s, void *args_uncast)
{
    struct func_cmd *args;
    args = args_uncast;

    args->func(args->type, args->format, s);

    return 0;
}
