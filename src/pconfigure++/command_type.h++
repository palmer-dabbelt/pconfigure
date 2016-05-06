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

#ifndef COMMAND_TYPE_HXX
#define COMMAND_TYPE_HXX

#include <cstring>
#include <string>
#include <vector>

/* Commands can consist of a number of different sorts of operations,
 * each of which is listed here.  Note that because the enum support
 * in C++ is kind of funky, if you modify this you're going to have to
 * modify a whole lot of stuff below...*/
enum class command_type {
    AUTODEPS,
    BINARIES,
    COMPAT,
    COMPILEOPTS,
    COMPILER,
    CONFIG,
    DEPLIBS,
    GENERATE,
    HDRDIR,
    HEADERS,
    LANGUAGES,
    LIBDIR,
    LIBEXECS,
    LIBRARIES,
    LINKER,
    LINKOPTS,
    PREFIX,
    SOURCES,
    SRCDIR,
    TESTDEPS,
    TESTDIR,
    TESTS,
    TESTSRC,
    TGENERATE,
    VERBOSE,
    VERSION,
    SRCPATH,
};

/* A utility function that allows one to iterate through all the
 * values inside the "command_type" enum. */
static const std::vector<command_type> all_command_types =
{
    command_type::AUTODEPS,
    command_type::BINARIES,
    command_type::COMPAT,
    command_type::COMPILEOPTS,
    command_type::COMPILER,
    command_type::CONFIG,
    command_type::DEPLIBS,
    command_type::GENERATE,
    command_type::HDRDIR,
    command_type::HEADERS,
    command_type::LANGUAGES,
    command_type::LIBDIR,
    command_type::LIBEXECS,
    command_type::LIBRARIES,
    command_type::LINKER,
    command_type::LINKOPTS,
    command_type::PREFIX,
    command_type::SOURCES,
    command_type::SRCDIR,
    command_type::TESTDEPS,
    command_type::TESTDIR,
    command_type::TESTS,
    command_type::TESTSRC,
    command_type::TGENERATE,
    command_type::VERBOSE,
    command_type::VERSION,
    command_type::SRCPATH,
};

/* Converts a command_type to a string, in the standard C++11 way. */
namespace std {
    static __inline__ std::string to_string(command_type cmd)
    {
        switch (cmd) {
        case command_type::AUTODEPS:
            return "AUTODEPS";
        case command_type::BINARIES:
            return "BINARIES";
        case command_type::COMPAT:
            return "COMPAT";
        case command_type::COMPILEOPTS:
            return "COMPILEOPTS";
        case command_type::COMPILER:
            return "COMPILER";
        case command_type::CONFIG:
            return "CONFIG";
        case command_type::DEPLIBS:
            return "DEPLIBS";
        case command_type::GENERATE:
            return "GENERATE";
        case command_type::HDRDIR:
            return "HDRDIR";
        case command_type::HEADERS:
            return "HEADERS";
        case command_type::LANGUAGES:
            return "LANGUAGES";
        case command_type::LIBDIR:
            return "LIBDIR";
        case command_type::LIBEXECS:
            return "LIBEXECS";
        case command_type::LIBRARIES:
            return "LIBRARIES";
        case command_type::LINKER:
            return "LINKER";
        case command_type::LINKOPTS:
            return "LINKOPTS";
        case command_type::PREFIX:
            return "PREFIX";
        case command_type::SOURCES:
            return "SOURCES";
        case command_type::SRCDIR:
            return "SRCDIR";
        case command_type::TESTDEPS:
            return "TESTDEPS";
        case command_type::TESTDIR:
            return "TESTDIR";
        case command_type::TESTS:
            return "TESTS";
        case command_type::TESTSRC:
            return "TESTSRC";
        case command_type::TGENERATE:
            return "TGENERATE";
        case command_type::VERBOSE:
            return "VERBOSE";
        case command_type::VERSION:
            return "VERSION";
        case command_type::SRCPATH:
            return "SRCPATH";
        }

        throw "Unable to convert " + to_string(static_cast<int>(cmd)) + " to string";
    }
}

/* Attempts to figure out exactly what sort of command matches the
 * given string.  This is written to be safe and small, not fast --
 * just don't use it a lot... :). */
static __inline__ command_type check_command_type(const std::string& str)
{
    for (const auto& cmd: all_command_types)
        if (strcasecmp(str.c_str(), std::to_string(cmd).c_str()) == 0)
            return cmd;

    throw "Unable to process " + str + " as command_type";
}

#endif
