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

#include "build_system.h++"
#include "build_systems/buildroot.h++"
#include "build_systems/kconfig.h++"
#include "build_systems/pconfigure.h++"

build_system::build_system(const std::string& name)
: _name(name),
  _base(),
  _context(NULL)
{
}

/* Drops the trailing '/' off a directory, which is the spelling that
 * every tool other than pconfigure's own bookkeeping wants. */
static std::string trim(const std::string& path)
{
    if (path.size() == 0)
        return ".";
    if (path[path.size() - 1] != '/')
        return path;
    return path.substr(0, path.size() - 1);
}

std::string build_system::source_dir(void) const
{
    return trim(_base);
}

std::string build_system::output_dir(void) const
{
    /* The build system comes first so that this can't land on top of
     * anything pconfigure puts in an object directory, and the
     * subproject second so that two trees built the same way can't
     * land on top of each other.
     *
     * That path is spelled the way it looks from inside the project
     * that owns the object directory: the object directory is already
     * based there, and basing the subproject again would produce
     * "sub/obj/kconfig/sub/linux". */
    return _context->obj_dir + "/" + _name
         + "/" + trim(_context->unbased(_base));
}

build_system::ptr build_system::bind(const std::string& base,
                                     const context::ptr& context) const
{
    auto out = dup();
    out->_base = base;
    out->_context = context;
    return out;
}

build_system::ptr build_system::create(const std::string& name)
{
    if (name == "pconfigure")
        return std::make_shared<build_system_pconfigure>(name);
    if (name == "kconfig")
        return std::make_shared<build_system_kconfig>(name);
    if (name == "buildroot")
        return std::make_shared<build_system_buildroot>(name);

    return NULL;
}

std::vector<std::string> build_system::names(void)
{
    return std::vector<std::string>{"pconfigure", "kconfig", "buildroot"};
}
