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

#ifndef STRING_UTILS_HXX
#define STRING_UTILS_HXX

#include <vector>
#include <string>

/* A collection of utilities that deal with simple string
 * operations. */
namespace string_utils {
    /* Cleans up the whitespace of a given string: removes all leading
     * and trailing spaces, and converts any internal whitespace to a
     * single space character. */
    std::string clean_white(const std::string& in);

    /* Splits a string into a number of sub-strings, making a new
     * sub-string every time any one of the delimiter characters is
     * found. */
    std::vector<std::string> split_char(const std::string& in,
                                        const std::string& delims);

    /* Joins the string using delim as the separator between
     * elements. */
    std::string join(const std::vector<std::string>& in,
                     const std::string& delim = "");

    /* Computes a simple hash code for a vector of strings. */
    std::string hash(const std::vector<std::string>& in);
}

#endif
