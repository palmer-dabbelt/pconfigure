
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

#ifndef FUNCS_H
#define FUNCS_H

#include "../stringlist.h"
#include <stdbool.h>

/* The general idea of this file is that without nested functions it
 * becomes very hard to do functional programming in C and still end
 * up with some semblence of type safety.  We provide type safety by
 * hiding all the unsafe junk in here.  This might not be the best
 * idea, but I guess at least it's something... */

/* Passes "pinclude_list" on to a printf-like function. */
void func_pinclude_list_printf(const char *full_path,
                               void (*func) (void *arg, const char *, ...),
                               void *arg, char **dirs);

/* Passes "pinclude_list" on to a string function. */
void func_pinclude_list_string(const char *full_path,
                               void (*func) (void *, const char *),
                               void *arg, char **dirs);

/* Passes "stringlist_each" on to a command function, in a manner such
 * that it will simply continue the current command in the Makefile.
 * This is a pretty common idiom, so it's been pulled out... */
void func_stringlist_each_cmd_cont(struct stringlist *sl,
                                   void (*func) (bool, const char *, ...));

/* This is almost exactly the same as "func_stringlist_each_cmd_cont",
 * but it adds a "-l" before every command. */
void func_stringlist_each_cmd_lcont(struct stringlist *sl,
                                    void (*func) (bool, const char *, ...));

/* This is almost exactly the same as "func_stringlist_each_cmd_cont",
 * except that it skips strings that start with the passed string. */
void func_stringlist_each_cmd_cont_nostart(struct stringlist *sl,
                                           void (*f) (bool, const char *,
                                                      ...), const char *skip);

/*  */

#endif
