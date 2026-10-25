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

#ifndef DEBUG_INFO_HXX
#define DEBUG_INFO_HXX

#include <memory>
#include <string>

/* Stores debug info that allows us to figure out where exactly
 * something came from when we're sitting deep inside command
 * processing somewhere. */
class debug_info {
public:
    typedef std::shared_ptr<debug_info> ptr;

private:
    const std::string _filename;
    const size_t _line_number;
    const std::string _line;
    const bool _command_line;

private:
    debug_info(const std::string& filename,
               size_t line_number,
               const std::string& line,
               bool command_line);

public:
    debug_info(const std::string& filename,
               size_t line_number,
               const std::string& line);

    /* A word on pconfigure's own command line rather than a line in a
     * Configfile.  The two are told apart by asking rather than by
     * looking at the filename, since "args" is a name a file could
     * have too.  It matters to anything that says what to write
     * instead: the same setting is spelled "STRICT = v0.13" in one
     * place and "--strict v0.13" in the other, and advice in the
     * wrong spelling is advice the reader has to translate first. */
    static std::shared_ptr<debug_info> command_line(size_t index,
                                                    const std::string& words);

public:
    const std::string& filename(void) const { return _filename; }
    const size_t& line_number(void) const { return _line_number; }
    const std::string& line(void) const { return _line; }
    bool from_command_line(void) const { return _command_line; }

    /* The same place with more of the command line quoted, for a flag
     * that turned out to take the word after it: a complaint about the
     * value has to show the value, and "args:1 '--strict'" shows
     * everything but. */
    std::shared_ptr<debug_info> with_line(const std::string& line) const;
};

namespace std {
    string to_string(const std::shared_ptr<debug_info>& di);
}

#endif
