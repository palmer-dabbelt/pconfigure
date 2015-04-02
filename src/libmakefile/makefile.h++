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

#ifndef LIBMAKEFILE__MAKEFILE_HXX
#define LIBMAKEFILE__MAKEFILE_HXX

#include <memory>
#include <vector>
#include "target.h++"

namespace makefile {
    /* Wraps up the data contained within a Makefile with objects so
     * you don't have to know too much about the text format of a
     * Makefile and can instead rely on simply generating some
     * objects. */
    class makefile {
    public:
        typedef std::shared_ptr<makefile> ptr;

        std::vector<target::ptr> _targets;

    private:

    public:
        /* Creates a new "empty" Makefile -- note that this actually
         * contains some about of default targets and such that you
         * don't want if you're going to be */
        makefile(void);

    public:
        /* Adds a target to this makefile. */
        void add_target(const target::ptr& target);
    };
}

#endif
