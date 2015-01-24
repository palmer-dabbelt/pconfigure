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

#ifndef COMMANDS_HXX
#define COMMANDS_HXX

#include "command.h++"
#include <vector>

/* Produces a list of commands that need to be handled by the system,
 * which can then be processed by something that actually understands
 * the meaning of those commands.  This is essentially just a way to
 * hide the fact that there's many command sources from the rest of
 * the system. */
std::vector<command::ptr> commands(int argc, const char **argv);

#endif
