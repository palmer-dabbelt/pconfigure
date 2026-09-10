/*
 * Copyright (C) 2026 Palmer Dabbelt
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

#include "context_file.h++"
#include "file_utils.h++"
#include <fstream>

bool context_file::read(
    const std::string& path,
    const std::function<void(const std::string&, const std::string&)>& handle)
{
    auto file = std::ifstream(path);
    if (file.good() == false)
        return false;

    auto line = std::string();
    while (std::getline(file, line)) {
        if (line.size() == 0)
            continue;

        auto space = line.find(' ');
        auto key = line.substr(0, space);
        auto value = space == std::string::npos
            ? std::string()
            : line.substr(space + 1);

        handle(key, value);
    }

    return true;
}

bool context_file::write(const std::string& path,
                         const std::string& body,
                         std::string& error)
{
    auto slash = path.find_last_of('/');
    if (slash != std::string::npos) {
        if (file_utils::mkdir_p(path.substr(0, slash)) == false) {
            error = "unable to create '" + path.substr(0, slash) + "'";
            return false;
        }
    }

    auto file = std::ofstream(path);
    if (file.good() == false) {
        error = "unable to write '" + path + "'";
        return false;
    }

    file << body;
    return true;
}

std::string context_file::join(const std::vector<std::string>& v)
{
    auto out = std::string();
    for (const auto& e: v) {
        if (out.size() > 0)
            out += " ";
        out += e;
    }
    return out;
}
