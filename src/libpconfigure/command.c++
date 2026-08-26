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

#include "command.h++"
#include "string_utils.h++"
#include <iostream>

command::command(const command_type& type,
                 const std::string& op,
                 const std::string& data,
                 const debug_info::ptr& debug_info,
                 const std::string& qualifier)
    : _type(type),
      _op(op),
      _data(data),
      _debug_info(debug_info),
      _needs_data(false),
      _qualifier(qualifier)
{
}

command::command(const command_type& type,
                 const std::string& op,
                 const debug_info::ptr& debug_info,
                 const std::string& qualifier)
    : _type(type),
      _op(op),
      _data(),
      _debug_info(debug_info),
      _needs_data(true),
      _qualifier(qualifier)
{
}

command::ptr command::with_type(const command_type& type)
{
    if (this->_needs_data)
        return std::make_shared<command>(
            type,
            this->_op,
            this->_debug_info,
            this->_qualifier);
    else
        return std::make_shared<command>(
            type,
            this->_op,
            this->_data,
            this->_debug_info,
            this->_qualifier);
}

command::ptr command::parse(const std::string& str,
                            const debug_info::ptr& d)
{
    if (str == "--verbose")
        return std::make_shared<command>(command_type::VERBOSE, "=", "true", d);
    if (str == "--version")
        return std::make_shared<command>(command_type::VERSION, "=", "true", d);
    if (str == "--help" || str == "-h")
        return std::make_shared<command>(command_type::HELP, "=", "true", d);
    if (str == "--config")
        return std::make_shared<command>(command_type::CONFIG, "+=", d);
    if (str == "--srcpath")
        return std::make_shared<command>(command_type::SRCPATH, "=", d);
    if (str == "--debug")
        return std::make_shared<command>(command_type::DEBUG, "=", "true", d);
    if (str == "--phc")
        return std::make_shared<command>(command_type::PHC, "=", d);
    if (str == "--cross-compile")
        return std::make_shared<command>(command_type::CROSS_COMPILE, "=", d);
    if (str == "--strict")
        return std::make_shared<command>(command_type::STRICT, "=", d);

    auto split = string_utils::split_char(str, " ");

    /* A command that sets something to nothing is written with the
     * value left off, since there's no way to write an empty word.
     * That's the only way to take back something a project was given
     * from further up -- a CROSS_COMPILE the whole project inherited,
     * for the one target that has to be built for this machine.
     *
     * CROSS_COMPILE is the only command it means anything for, and
     * the only one allowed to be written that way.  Everything else
     * that takes an '=' names a place rather than a choice, and an
     * empty answer to "where" isn't a project saying "nowhere", it's
     * a line somebody got wrong: an empty LIBDIR would quietly make
     * every library path in the build absolute. */
    auto sets_nothing = (split.size() == 2)
        && (split[1] == "=")
        && (strcasecmp(split[0].c_str(),
                       std::to_string(command_type::CROSS_COMPILE).c_str())
            == 0);

    if (split.size() < 3 && sets_nothing == false) {
        std::cerr << "split_char() returned " << split.size() << "\n"
                  << "  original string: '" << str << "'\n";
        return NULL;
    }

    auto cmdstr = split[0];
    auto op = split[1];

    /* A command can be written with a name in brackets, which says
     * which of several things of that kind the line lands on.  It
     * belongs to the command rather than to the value: everything
     * after the operator is what the line is about, and the brackets
     * come before it.
     *
     * The name ends the command, so a line that opens the brackets
     * and doesn't close them is a line with no command on it at all.
     * Reading it as far as the '[' and carrying on would take a
     * mistyped name as a command written without one, which is a
     * different command that works. */
    auto qualifier = std::string();
    auto open = cmdstr.find('[');
    if (open != std::string::npos) {
        if (cmdstr[cmdstr.size() - 1] != ']') {
            std::cerr << std::to_string(d) << "\n"
                      << "  error: '" << cmdstr << "' opens a name in"
                      << " brackets and never closes it\n"
                      << "  a command that carries a name ends at the"
                      << " ']', so everything from the '[' onwards is"
                      << " part of the command\n";
            abort();
        }

        qualifier = cmdstr.substr(open + 1, cmdstr.size() - open - 2);
        cmdstr = cmdstr.substr(0, open);

        if (qualifier.size() == 0) {
            std::cerr << std::to_string(d) << "\n"
                      << "  error: '" << cmdstr << "[]' has nothing"
                      << " between its brackets\n"
                      << "  write the name in them, or leave the brackets"
                      << " off: an empty name is not the same thing as"
                      << " no name\n";
            abort();
        }
    }
    auto arg = sets_nothing
        ? std::string()
        : std::string(str, split[0].size() + split[1].size() + 2);

    try {
        auto cmd = check_command_type(cmdstr);
        return std::make_shared<command>(cmd, op, arg, d, qualifier);
    } catch (const char *e) {
        std::cerr << "Unable to parse command: '" << e << "'\n";
        return NULL;
    }  catch (const std::string& e) {
        std::cerr << "Unable to parse command: '" << e << "'\n";
        return NULL;
    } catch(...) {
        std::cerr << "Unknown exception type when parsing command\n";
        return NULL;
    }
}

command::ptr command::consume_extra_arguments(int& i, int argc,
                                              const char **argv)
{
    if (_needs_data == false)
        return shared_from_this();

    /* The argument this wants is the one after the flag, so it's that
     * one that has to be there.  Asking whether the flag itself is in
     * range is asking about something already known, and it let a
     * flag written last on the command line read one past the end. */
    if (i + 1 >= argc)
        return nullptr;

    return std::make_shared<command>(
        this->_type,
        this->_op,
        argv[++i],
        this->_debug_info,
        this->_qualifier
    );
}
