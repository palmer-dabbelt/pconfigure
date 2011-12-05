
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

#ifndef LANGUAGES_BASH_H
#define LANGUAGES_BASH_H

#include "language.h"
#include "../target.h"

struct language_bash
{
    /* This is a subclass of language, all other definitions must be after
     * this line */
    struct language l;

};

/* Initializes the C language */
enum error language_bash_boot(void);
enum error language_bash_halt(void);

/* Returns a pointer to the (static) C language, if the name matches */
struct language *language_bash_add(const char *name);

#endif
