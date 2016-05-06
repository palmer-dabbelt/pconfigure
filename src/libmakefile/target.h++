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

#ifndef LIBMAKEFILE__TARGET_HXX
#define LIBMAKEFILE__TARGET_HXX

#include "global_targets.h++"
#include <memory>
#include <vector>

namespace makefile {
    /* A fully-generated Makefile target, which contains a large batch of  */
    class target {
    public:
        typedef std::shared_ptr<target> ptr;
        friend bool same_recipe(const target::ptr& a, const target::ptr& b);

    private:
        const std::string _name;
        const std::string _short_cmd;
        const std::vector<target::ptr> _deps;
        const std::vector<global_targets> _global;
        const std::vector<std::string> _cmds;
        const std::vector<std::string> _comment;

    public:
        /* Creates a new target fully-fledged target -- this is a
         * target that the Makefile actually knows how to generate. */
        target(const std::string& name,
               const std::string& short_cmd,
               const std::vector<target::ptr>& deps,
               const std::vector<global_targets>& global,
               const std::vector<std::string>& cmds,
               const std::vector<std::string>& comment);

        /* Creates a new target that the Makefile can't generate --
         * this is something that must exist in the filesystem
         * already. */
        target(const std::string& name);

    public:
        /* Accessor methods. */
        const std::string& name(void) const { return _name; }

    public:
        /* Returns a copy of this target without the given global target. */
        ptr without(global_targets g) const;

        /* Returns TRUE if this target is a dependency of the given global
         * target. */
        bool has_global_target(const global_targets& g) const;

    public:
        /* Writes this target (and with its commands) to the given
         * file. */
        void write_to_file(FILE *file, bool verbose) const;
    };

    /* Returns TRUE if two targets have equivilant recipes.  Note that you
     * can't rely on this doing anything between a perfect equivilance match
     * and a string comparison, since it currently does string compare but I
     * might have to extend it. */
    bool same_recipe(const target::ptr& a, const target::ptr& b);
}

#endif
