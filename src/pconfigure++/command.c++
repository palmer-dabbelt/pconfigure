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
                 const debug_info::ptr& debug_info)
    : _type(type),
      _debug_info(debug_info)
{
}

command::ptr command::parse(const std::string& str,
                            const debug_info::ptr& d)
{
    auto split = string_utils::split_char(str, " ");
    if (split.size() < 3) {
        std::cerr << "split_char() returned " << split.size() << "\n"
                  << "  original string: '" << str << "'\n";
        return NULL;
    }

    auto cmdstr = split[0];
    auto op = split[1];
    auto arg = std::string(str, split[0].size() + split[1].size() + 2);

    try {
        auto cmd = check_command_type(cmdstr);
        return std::make_shared<command>(cmd, d);
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
