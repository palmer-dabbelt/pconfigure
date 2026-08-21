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

/* A line of a Configfile, exactly as it was written.
 *
 * Lines are handed out rather than commands because turning one into
 * a command can mean running a program -- anything in backticks --
 * and when that program runs matters: a Configfile that asks
 * pkg-config about a package one of its own subprojects builds only
 * gets a useful answer if the subproject has been read by then. */
class configfile_line {
public:
    /* Not const, only because these end up in vectors that get
     * spliced together. */
    std::string filename;
    size_t number;
    std::string text;

    configfile_line(const std::string& filename,
                    size_t number,
                    const std::string& text)
    : filename(filename), number(number), text(text)
    {}
};

/* The lines of the default Configfiles of the project rooted at the
 * given source path. */
std::vector<configfile_line> configfile_lines(const std::string& srcpath);

/* The lines of the Configfiles with the given suffix, which is what a
 * CONFIG command asks for. */
std::vector<configfile_line> config_lines(const std::string& srcpath,
                                          const std::string& prefix,
                                          const std::string& suffix);

/* The lines of a file with exactly this name.  The source path is
 * only used to find executable Configfiles, which are run with it as
 * their working directory. */
std::vector<configfile_line> lines_from_file(const std::string& srcpath,
                                             const std::string& filename);

/* Turns a line into a command, running whatever it has in backticks
 * along the way.  Returns NULL for a line that says nothing, which is
 * an empty one or a comment. */
command::ptr parse_line(const configfile_line& line);

/* Adds a directory holding pkg-config files that this run knows how
 * to build, which is what lets a project ask about a package one of
 * its subprojects provides before anything has been built.  Every
 * pkg-config a Configfile runs looks here first. */
void add_pkgconfig_path(const std::string& dir);

#endif
