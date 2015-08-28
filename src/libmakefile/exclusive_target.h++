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

#ifndef LIBMAKEFILE__EXCLUSIVE_TARGET_HXX
#define LIBMAKEFILE__EXCLUSIVE_TARGET_HXX

#include "target.h++"

namespace makefile {
    /* A special sort of target that uses a global string in order
     * to ensure that */
    class exclusive_target: public target {
    public:
        typedef std::shared_ptr<exclusive_target> ptr;

    public:
        /* Much like the long target() call, but this takes a stamp
         * file to produce instead. */
        exclusive_target(const std::string& key,
                         const std::string& name,
                         const std::string& short_cmd,
                         const std::vector<target::ptr>& deps,
                         const std::vector<global_targets>& global,
                         const std::vector<std::string>& cmds,
                         const std::vector<std::string>& comment);
    };
}

#endif
