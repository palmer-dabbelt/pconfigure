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

#ifndef CONTEXT_TYPE_HXX
#define CONTEXT_TYPE_HXX

#include <cstring>
#include <string>
#include <vector>

/* There are a small number of context types, each of which ends up
 * being generated directly from one of the sources. */
enum class context_type {
    DEFAULT,
    GENERATE,
    LIBRARY,
    SOURCE,
    BINARY,
    TEST,
    HEADER,
};

/* A utility function that allows one to iterate through all the
 * values inside the "command_type" enum. */
static const std::vector<context_type> all_context_types =
{
    context_type::DEFAULT,
    context_type::GENERATE,
    context_type::LIBRARY,
    context_type::SOURCE,
    context_type::BINARY,
    context_type::TEST,
    context_type::HEADER,
};

/* Converts a command_type to a string, in the standard C++11 way. */
namespace std {
    static __inline__ std::string to_string(context_type cmd)
    {
        switch (cmd) {
        case context_type::DEFAULT:
            return "DEFAULT";
        case context_type::GENERATE:
            return "GENERATE";
        case context_type::LIBRARY:
            return "LIBRARY";
        case context_type::SOURCE:
            return "SOURCE";
        case context_type::BINARY:
            return "BINARY";
        case context_type::TEST:
            return "TEST";
        case context_type::HEADER:
            return "HEADER";
        }

        throw "Unable to convert " + to_string(static_cast<int>(cmd)) + " to string";
    }
}

/* Attempts to figure out exactly what sort of context matches the
 * given string.  This is written to be safe and small, not fast --
 * just don't use it a lot... :). */
static __inline__ context_type check_context_type(const std::string& str)
{
    for (const auto& ctx: all_context_types)
        if (strcasecmp(str.c_str(), std::to_string(ctx).c_str()) == 0)
            return ctx;

    throw "Unable to process " + str + " as command_type";
}

#endif
