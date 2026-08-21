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
                 const debug_info::ptr& debug_info)
    : _type(type),
      _op(op),
      _data(data),
      _debug_info(debug_info),
      _needs_data(false)
{
}

command::command(const command_type& type,
                 const std::string& op,
                 const debug_info::ptr& debug_info)
    : _type(type),
      _op(op),
      _data(),
      _debug_info(debug_info),
      _needs_data(true)
{
}

command::ptr command::with_type(const command_type& type)
{
    if (this->_needs_data)
        return std::make_shared<command>(
            type,
            this->_op,
            this->_debug_info);
    else
        return std::make_shared<command>(
            type,
            this->_op,
            this->_data,
            this->_debug_info);
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
    auto arg = sets_nothing
        ? std::string()
        : std::string(str, split[0].size() + split[1].size() + 2);

    try {
        auto cmd = check_command_type(cmdstr);
        return std::make_shared<command>(cmd, op, arg, d);
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

    if (i >= argc)
        return nullptr;

    return std::make_shared<command>(
        this->_type,
        this->_op,
        argv[++i],
        this->_debug_info
    );
}
