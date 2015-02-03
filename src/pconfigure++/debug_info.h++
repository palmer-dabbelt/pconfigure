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

public:
    debug_info(const std::string& filename,
               size_t line_number,
               const std::string& line);

public:
    const std::string& filename(void) const { return _filename; }
    const size_t& line_number(void) const { return _line_number; }
    const std::string& line(void) const { return _line; }
};

namespace std {
    string to_string(const std::shared_ptr<debug_info>& di);
}

#endif
