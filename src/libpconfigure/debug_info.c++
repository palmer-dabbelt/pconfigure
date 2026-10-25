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
      _line(line),
      _command_line(false)
{
}

debug_info::debug_info(const std::string& filename,
                       size_t line_number,
                       const std::string& line,
                       bool command_line)
    : _filename(filename),
      _line_number(line_number),
      _line(line),
      _command_line(command_line)
{
}

std::shared_ptr<debug_info> debug_info::command_line(size_t index,
                                                     const std::string& words)
{
    /* Not make_shared(), which can't reach a private constructor. */
    return std::shared_ptr<debug_info>(
        new debug_info("args", index, words, true));
}

std::shared_ptr<debug_info> debug_info::with_line(const std::string& line) const
{
    return std::shared_ptr<debug_info>(
        new debug_info(_filename, _line_number, line, _command_line));
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

