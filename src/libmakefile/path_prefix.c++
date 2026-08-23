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

#include "path_prefix.h++"
#include <cctype>

/* The characters that end one word of a command line and start the
 * next, which is where a path is allowed to begin. */
static bool separates_words(char c)
{
    if (isspace(c))
        return true;

    switch (c) {
    case '=':
    case ',':
    case ':':
    case ';':
    case '"':
    case '\'':
    case '(':
    case '|':
    case '&':
    case '<':
    case '>':
    case '^':
        return true;
    default:
        return false;
    }
}

/* TRUE when a path is allowed to start at "i". */
static bool starts_path(const std::string& line, size_t i)
{
    if (i == 0)
        return true;

    /* Something already came before this, so whatever's here is the
     * tail of a longer path rather than the start of one.  This is
     * what protects absolute paths. */
    if (line[i - 1] == '/')
        return false;

    if (separates_words(line[i - 1]) == true)
        return true;

    /* Otherwise this is in the middle of a word, which is only a path
     * if the word is a flag that takes its argument stuck to it --
     * "-Isub/include", "-osub/bin/x".  The argument starts right
     * after the two characters of the flag and nowhere else: a match
     * further in is some directory's name that happens to end the
     * same way, and rewriting it turns "obj/lib/x" into
     * "obj/li$(sub)x".  A flag written any longer than that hands its
     * argument over with a ',' or an '=' in between, and both of
     * those already end a word. */
    auto start = i;
    while (start > 0 && separates_words(line[start - 1]) == false)
        start--;

    return line[start] == '-' && i == start + 2;
}

std::string makefile::path_prefix::rewrite(const std::string& line) const
{
    if (included() == false)
        return line;
    if (_base.size() == 0)
        return line;

    auto out = std::string();

    size_t i = 0;
    while (i < line.size()) {
        /* Longest directory first, so that a project nested inside
         * another one is named through its own variable rather than
         * through its parent's and a leftover directory.  Either
         * spelling would mean the right file; only one of them says
         * which project the file belongs to. */
        auto matched = false;
        for (const auto& match: _matches) {
            if (line.compare(i, match.first.size(), match.first) != 0)
                continue;
            if (starts_path(line, i) == false)
                continue;

            out += match.second;
            i += match.first.size();
            matched = true;
            break;
        }

        if (matched == true)
            continue;

        out += line[i];
        i++;
    }

    return out;
}
