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

#include "string_utils.h++"
#include <cstring>
#include <iostream>
#include <sstream>
using namespace string_utils;

std::string string_utils::clean_white(const std::string& in)
{
    char *dup = strdup(in.c_str());

    size_t oi = 0;
    bool white = true;
    for (size_t ii = 0; ii < strlen(in.c_str()); ++ii) {
        auto was_white = white;
        white = isspace(in.c_str()[ii]);

        if (white && was_white)
            continue;

        dup[oi] = white ? ' ' : in.c_str()[ii];
        oi++;
    }
    dup[oi] = '\0';

    /* If the string is of 0 length then there's nothing left to do
     * here, so just don't worry about it any more. */
    if (strlen(dup) == 0)
        goto valid;

    /* That last loop can leave a single trailing white space, check
     * for that and remove it here. */
    if (isspace(dup[strlen(dup)-1]))
        dup[strlen(dup)-1] = '\0';

valid:
    std::string out = dup;
    free(dup);
    return out;
}

#ifdef TEST_CLEAN_WHITE
int main(int argc, char **argv)
{
    if (argc != 2)
        return -1;

    std::cout << string_utils::clean_white(argv[1]).c_str() << "\n";
    return 0;
}
#endif

std::vector<std::string> string_utils::split_char(const std::string& in,
                                                  const std::string& delims)
{
    std::vector<std::string> out;

    size_t offset = 0;
    while (offset != std::string::npos) {
        auto end = in.find_first_of(delims, offset);
        if (end == std::string::npos)
            break;

        out.push_back(std::string(in, offset, end - offset));
        offset = end + 1;
    }

    if (offset != std::string::npos)
        out.push_back(std::string(in, offset));

    return out;
}

#ifdef TEST_STRIP_CHAR
int main(int argc, char **argv)
{
    if (argc != 3)
        return -1;

    for (const auto& spl: string_utils::split_char(argv[1], argv[2]))
        std::cout << spl << "\n";

    return 0;
}
#endif

std::string string_utils::join(const std::vector<std::string>& in,
                               const std::string& delim)
{
    std::ostringstream ss;
    for(auto i = in.size()*0; i < in.size(); ++i) {
        if (i != 0)
            ss << delim;
        ss << in[i];
    }
    return ss.str();
}

/* Computes a simple hash code for a vector of strings. */
std::string string_utils::hash(const std::vector<std::string>& in)
{
    unsigned long hash = 5381;

    for (const auto& str: in)
        for (const auto& chr: str)
            hash = ((hash << 5) + hash) + chr;

    return std::to_string(hash);
}
