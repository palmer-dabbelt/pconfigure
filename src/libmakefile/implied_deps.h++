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

#ifndef LIBMAKEFILE__IMPLIED_DEPS_HXX
#define LIBMAKEFILE__IMPLIED_DEPS_HXX

#include "target.h++"
#include <string>
#include <vector>

namespace makefile {
    /* Something one target can do for another, tied to the target
     * that either offers it or wants it.
     *
     * What a capability is called is entirely up to whoever produced
     * the target: this side of things only ever compares the names to
     * each other.  That's deliberate, because deciding that a link
     * line reading "-Llib -lfoo" wants whatever produces
     * "lib/libfoo.so" means knowing the syntax of a particular
     * compiler, which is not something a Makefile should have an
     * opinion about. */
    class capability {
    public:
        const std::string name;
        const std::string target;

        capability(const std::string& name, const std::string& target)
        : name(name), target(target)
        {}
    };

    /* A dependency that nobody wrote down, but that falls out of one
     * target wanting something another target offers. */
    class implied_dep {
    public:
        const std::string target;
        const std::string dep;

        implied_dep(const std::string& target, const std::string& dep)
        : target(target), dep(dep)
        {}
    };

    /* Matches up what targets want against what targets offer,
     * producing the dependencies that implies.
     *
     * This has to see every target at once, from every project: a
     * subproject that's read late can perfectly well provide
     * something the project that pulled it in wanted early, so
     * nothing here may depend on the order things were parsed in.
     *
     * A match only becomes a dependency if something actually knows
     * how to build the target that offered it -- which is what keeps
     * a reference to a system library from turning into a dependency
     * on a target that doesn't exist -- and if it isn't already
     * written down, and if it wouldn't introduce a cycle. */
    std::vector<implied_dep>
    implied_deps(const std::vector<target::ptr>& targets,
                 const std::vector<capability>& provided,
                 const std::vector<capability>& needed);
}

#endif
