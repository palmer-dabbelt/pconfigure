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

#ifndef COMMAND_HXX
#define COMMAND_HXX

#include <memory>
#include "command_type.h++"
#include "debug_info.h++"

/* Represents */
class command;
class command: public std::enable_shared_from_this<command> {
public:
    typedef std::shared_ptr<command> ptr;

private:
    const command_type _type;
    const std::string _op;
    const std::string _data;
    const debug_info::ptr _debug_info;
    const bool _needs_data;

    /* The name the command was written with in brackets, or empty
     * when it was written without one.  This is part of the command
     * rather than of its value: "TESTS[network]" is a TESTS, and what
     * the brackets hold says which of several things of that kind the
     * line lands on. */
    const std::string _qualifier;

    /* The command as the Configfile spelled it, which is the same as
     * _type for every command but the copies with_type() makes.  A
     * TESTSRC is handled as a TESTS and then a SOURCES, and whatever
     * the SOURCES half refuses it has to refuse in the words of the
     * line that was actually written: a diagnostic that says
     * "SOURCES" about a TESTSRC sends whoever reads it looking for a
     * line that isn't there.  Not const only because with_type() sets
     * it on the copy after building it. */
    command_type _written_as;

    /* TRUE for a line whose value was written as backticks that
     * printed nothing, which left it with no value at all.  That is
     * not the same line as one written without a value, which is
     * refused as unfinished before it gets this far: whether a command
     * can be given nothing is a question about the command, and only
     * the command processor knows which ones can. */
    const bool _printed_nothing;

public:
    command(const command_type& type,
            const std::string& op,
            const std::string& data,
            const debug_info::ptr& debug_info,
            const std::string& qualifier = "",
            bool printed_nothing = false);
    command(const command_type& type,
            const std::string& op,
            const debug_info::ptr& debug_info,
            const std::string& qualifier = "");

public:
    command_type type(void) const { return _type; }
    const std::string& operation(void) const { return _op; }
    const std::string data(void) const { return _data; }
    const debug_info::ptr& debug(void) const { return _debug_info; }
    const std::string& qualifier(void) const { return _qualifier; }
    command_type written_as(void) const { return _written_as; }
    bool printed_nothing(void) const { return _printed_nothing; }

public:
    ptr consume_extra_arguments(int& i, int argc, const char **argv);

public:
    /* Checks to make sure that the command's operation is exactly
     * what is requested and returns TRUE, otherwise returns FALSE. */
    bool check_operation(const std::string& allowed_op)
        { return operation() == allowed_op; }
    
    /* Copies this command, but gives it a different type.  The copy
     * still remembers what was written, as written_as(). */
    ptr with_type(const command_type& type);

    /* Copies this command, but gives it a different value.  Every
     * other part of the line -- where it was written, what it was
     * written with -- stays what it was, so a diagnostic about the
     * copy still points at the line that said it. */
    ptr with_data(const std::string& data);

public:
    /* Converts a command string (as stored in the Configfile or as a
     * command-line argument) into an actual command object that's a
     * whole lot safer. */
    static ptr parse(const std::string& str, const debug_info::ptr& d,
                     bool printed_nothing = false);

    /* Just the half of parse() that knows pconfigure's own options,
     * matched exactly as they were typed: NULL for any other word.
     * The command line asks this first, because a word that isn't an
     * option is a Configfile line, and a Configfile line is tidied
     * and has its backticks run before it's read -- which an option,
     * and the word after one, must not be. */
    static ptr parse_option(const std::string& str,
                            const debug_info::ptr& d);
};

#endif
