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

#include "debug_info.h++"

debug_info::debug_info(const std::string& filename,
                       size_t line_number,
                       const std::string& line)
    : _filename(filename),
      _line_number(line_number),
      _line(line)
{
}

std::string std::to_string(const std::shared_ptr<debug_info>& di)
{
    return di->filename()
        + std::string(":")
        + std::to_string(di->line_number())
        + std::string(" '")
        + di->line()
        + std::string("'");
}

