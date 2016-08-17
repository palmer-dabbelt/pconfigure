/*
 * Copyright (C) 2016 Palmer Dabbelt
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

#ifndef PICK_LANGUAGE_HXX
#define PICK_LANGUAGE_HXX

#include "command_processor.h++"
#include "context.h++"
#include "language.h++"
#include "language_list.h++"

/* Picks the language that will be used to compile a context.  This gets used
 * in multiple places (main and in the TESTS language support, for example). */
language::ptr pick_language(const language_list::ptr& languages,
                            const context::ptr& context);

#endif
