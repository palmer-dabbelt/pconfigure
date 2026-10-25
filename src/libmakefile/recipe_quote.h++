/*
 * Copyright (C) 2026 Palmer Dabbelt
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

#ifndef LIBMAKEFILE__RECIPE_QUOTE_HXX
#define LIBMAKEFILE__RECIPE_QUOTE_HXX

#include <string>

namespace makefile {
    /* A word the shell reads back as exactly these bytes, inside a
     * recipe make hands it: single quotes for the shell, with the one
     * character they can't hold closed around, and every '$' doubled
     * for make -- which expands a recipe before the shell ever sees
     * it, quotes or not.
     *
     * Only for recipe lines.  A '#' is left alone, which is right
     * there -- make hands a recipe to the shell without looking for
     * comments, and the shell reads a '#' in the middle of a word as
     * part of it -- and wrong anywhere make reads the text as a rule,
     * where the quotes would be part of the file name besides. */
    std::string recipe_quoted(const std::string& text);
}

#endif
