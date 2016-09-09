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

#ifndef PINCLUDE_HXX
#define PINCLUDE_HXX

#include <functional>
#include <string>
#include <vector>

namespace pinclude {
    /* Looks through the given file for #include lines, calling the given
     * callback for any included file that exists inside one of the given
     * include_dirs.  This handles some simple CPP #define-related things, the
     * list of default definitions is given in defined.  Any non-zero return
     * value from the callback stops parsing and returns that value. */
    int list(std::string filename,
             std::vector<std::string> include_dirs,
             std::vector<std::string> defined,
             std::function<int(std::string)> callback,
             bool skip_missing_files);

    int list(std::string filename,
             std::function<int(std::string)> callback,
             bool skip_missing_files)
    {
        return list(filename,
                    std::vector<std::string>{},
                    std::vector<std::string>{},
                    callback,
                    skip_missing_files
                );
    }
}

#endif
