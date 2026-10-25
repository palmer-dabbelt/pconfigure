/*
 * Copyright (C) 2013,2016 Palmer Dabbelt
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

#include <pinclude.h++>
#include <string>
#include <cstring>
#include <iostream>
#include <unordered_set>

int main(int argc, const char **argv)
{
    std::vector<std::string> dirs;
    std::unordered_set<std::string> defs;
    std::string input;

    /* "-I" and "-D" are taken both glued to what they carry and as a
     * word of their own, because that is how a compiler takes them,
     * and how pconfigure and pbashc read the same flags out of a
     * COMPILEOPTS.  Only the glued spelling used to be understood
     * here: "-I inc" came out as a search directory with an empty
     * name and an "inc" that, being a bare word, became the file to
     * read until the real one came along and replaced it, so every
     * header in "inc" was looked for at the root instead.
     *
     * The scan tracks which names are defined rather than what they
     * are defined as, and "-DNAME=value" defines NAME every bit as
     * much as "-DNAME" does.  Kept whole, "NAME=value" was a macro no
     * "#ifdef" has ever asked about, and whatever it guarded was left
     * off the list.  A function-like "-DNAME(args)", with or without
     * a body, defines NAME too, so the name stops at a '(' as well. */
    for (int i = 1; i < argc; ++i) {
        std::string flag;
        std::string value;

        if (strcmp(argv[i], "-I") == 0 || strcmp(argv[i], "-D") == 0) {
            flag = argv[i];
            if (i + 1 >= argc) {
                std::cerr << "'" << flag << "' needs something after it\n"
                          << "  a search directory is '-I dir' or '-Idir', "
                          << "and a definition '-D name' or '-Dname'\n";
                return 1;
            }
            value = argv[++i];
        } else if (strncmp(argv[i], "-I", 2) == 0
                   || strncmp(argv[i], "-D", 2) == 0) {
            flag = std::string(argv[i], 2);
            value = argv[i] + 2;
        } else {
            input = argv[i];
            continue;
        }

        if (flag == "-I")
            dirs.push_back(value);
        else
            defs.insert(value.substr(0, value.find_first_of("=(")));
    }

    return pinclude::list(
        input,
        dirs,
        defs,
        [](std::string filename) -> int {
            std::cout << filename << "\n";
            return 0;
        },
        true
    );
}
