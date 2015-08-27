/*
 * Copyright (C) 2015 Palmer Dabbelt
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

#ifndef FILE_UTILS_HXX
#define FILE_UTILS_HXX

#include <vector>
#include <string>

/* A collection of utilities that deal with files on disk.  This is
 * kind of just a grab bag of stuff that I was hoping would be used a
 * few times throughout the project. */
namespace file_utils {
    /* Returns every line of a file converted into a std::vector. */
    std::vector<std::string> readlines(FILE *f);

    /* Like readlines(), but also returns the line number (1-indexed)
     * for each line that is read from the file.  Useful for parsing
     * files and such.  */
    struct line_and_number {
        std::string line;
        size_t number;
    };
    std::vector<struct line_and_number> readlines_and_numbers(FILE *f);

    /* Like readlines(), but executes the input file with the given
     * argument list. */
    std::vector<std::string> execlines(
        std::string path,
        std::vector<std::string> args = std::vector<std::string>()
        );
}

#endif
