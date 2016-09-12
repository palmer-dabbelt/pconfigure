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

    for (int i = 1; i < argc; ++i) {
        if (strncmp(argv[i], "-I", 2) == 0)
            dirs.push_back(argv[i] + 2);
        else if (strncmp(argv[i], "-D", 2) == 0)
            defs.insert(argv[i] + 2);
        else
            input = argv[i];
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
