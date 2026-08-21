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

#include "pconfigure.h++"
#include <unistd.h>
#include <iostream>

build_system_pconfigure::build_system_pconfigure(const std::string& name)
: build_system(name)
{
}

build_system* build_system_pconfigure::clone(void) const
{
    return new build_system_pconfigure(*this);
}

bool build_system_pconfigure::can_build(const std::string& base) const
{
    /* The same files that get read when pconfigure is run in a
     * directory, minus the local ones: a Configfile.local is
     * somebody's private overrides, and a directory that has nothing
     * but one of those isn't a project. */
    return access((base + "Configfile").c_str(), R_OK) == 0
        || access((base + "Configfiles/main").c_str(), R_OK) == 0;
}

void build_system_pconfigure::add_configureopt(const std::string& opt)
{
    std::cerr << "CONFIGUREOPTS doesn't apply to a pconfigure subproject: '"
              << opt << "'\n"
              << "  a pconfigure project is configured by its own"
              << " Configfile\n";
    abort();
}

std::vector<makefile::target::ptr>
build_system_pconfigure::targets(void) const
{
    return std::vector<makefile::target::ptr>();
}
