
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

#ifndef LANGUAGES_H
#define LANGUAGES_H

#include "error.h"
#include "languages/language.h"
#include "target.h"

/* Initializes the languages module */
enum error languages_boot(void);
enum error languages_halt(void);

/* Adds a single language to the list of currently availiable languages */
enum error languages_add(const char *name);

/* Returns the last language added, or NULL if no languages have been added */
struct language *languages_last_added(void);

/* Finds a language that can compile the given source file */
struct language *languages_search(struct target *t);

#endif
