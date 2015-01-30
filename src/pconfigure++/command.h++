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
class command {
public:
    typedef std::shared_ptr<command> ptr;

private:
    command_type _type;
    debug_info::ptr _debug_info;

public:
    command(const command_type& type,
            const debug_info::ptr& debug_info);

public:
    command_type type(void) const { return _type; }

public:
    /* Converts a command string (as stored in the Configfile or as a
     * command-line argument) into an actual command object that's a
     * whole lot safer. */
    static ptr parse(const std::string& str, const debug_info::ptr& d);
};

#endif
