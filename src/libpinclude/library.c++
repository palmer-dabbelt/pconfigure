/*
 * Copyright (C) 2016 Palmer Dabbelt
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

#include <pinclude.h++>
#include <pinclude.h>

class pinclude_args {
public:
    const std::function<int(std::string)> func;
    pinclude_args(const std::function<int(std::string)> _func)
    : func(_func)
    {} 
};
static int pinclude_callback(const char *path, void *args_uncase);

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs,
                   std::vector<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files)
{
    size_t defines_i = 0;
    const char **defines_a = new const char*[defines.size() + 1];
    size_t include_dirs_i = 0;
    const char **include_dirs_a = new const char*[include_dirs.size() + 1];

    for (const auto& include_dir: include_dirs)
        include_dirs_a[include_dirs_i++] = include_dir.c_str();
    include_dirs_a[include_dirs_i] = nullptr;

    for (const auto& define: defines)
        defines_a[defines_i++] = define.c_str();
    defines_a[defines_i] = nullptr;

    auto args = pinclude_args(callback);
    auto out = pinclude_list(filename.c_str(),
                             &pinclude_callback,
                             &args,
                             &include_dirs_a[0],
                             &defines_a[0],
                             skip_missing_files ? 1 : 0);

    delete[] defines_a;
    delete[] include_dirs_a;

    return out;
 
}

int pinclude_callback(const char *path, void *args_uncast)
{
    auto args = (class pinclude_args*)args_uncast;
    return args->func(path);
}
