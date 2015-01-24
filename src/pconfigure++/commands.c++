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

#include "commands.h++"

std::vector<command::ptr> commands(int argc, const char **argv)
{
    std::vector<command::ptr> out;

    for (auto i = 1; i < argc; ++i) {
        auto cmd = command::parse(argv[i]);
        if (cmd == NULL) {
            fprintf(stderr, "Unable to parse command-line option %d: '%s'\n",
                    i - 1,
                    argv[i]
                );
            abort();
        }

        out.push_back(cmd);
    }

    return out;
}
