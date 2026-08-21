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

#ifndef BUILD_SYSTEMS__PCONFIGURE_HXX
#define BUILD_SYSTEMS__PCONFIGURE_HXX

#include "../build_system.h++"

/* pconfigure itself, which is the build system a SUBPROJECTS gets
 * when the directory it names has a Configfile in it.
 *
 * There's an implicit "BUILD_SYSTEMS += pconfigure" at the bottom of
 * every project, so this is always available and always asked first:
 * a tree that says how to build itself the pconfigure way meant it.
 *
 * This produces no targets of its own.  A pconfigure subproject isn't
 * run as a build system at all -- it's read into this run, and its
 * targets come out of its own contexts like anybody else's. */
class build_system_pconfigure: public build_system {
public:
    build_system_pconfigure(const std::string& name);
    virtual ~build_system_pconfigure(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;
    bool vendored(void) const { return false; }
    void add_configureopt(const std::string& opt);
    std::vector<makefile::target::ptr>
    targets(const std::vector<ptr>& peers) const;
};

#endif
