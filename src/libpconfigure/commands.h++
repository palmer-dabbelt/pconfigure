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

/* Produces the list of commands that were given on the command line.
 * Note that this doesn't include anything that comes from a
 * Configfile: those are read seperately, after the command-line
 * options have been processed (as they can change where the
 * Configfiles are read from). */
std::vector<command::ptr> commands(int argc, const char **argv);

/* Produces a list of commands that come from a file with the given
 * suffix, looked up relative to the given source path. */
std::vector<command::ptr> commands(const std::string& srcpath,
                                   const std::string& prefix,
                                   const std::string& suffix);

/* Produces a list of commands that come from the default Configfiles
 * of the project rooted at the given source path. */
std::vector<command::ptr> configfiles(const std::string& srcpath);

/* Produces a list of commands that come from a file with exactly this
 * name.  The source path is only used to find executable Configfiles,
 * which are run with it as their working directory. */
std::vector<command::ptr> commands_from_file(const std::string& srcpath,
                                             const std::string& filename);

#endif
