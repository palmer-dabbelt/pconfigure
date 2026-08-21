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

#include "buildroot.h++"
#include "../file_utils.h++"
#include <sys/stat.h>
#include <unistd.h>
#include <iostream>

build_system_buildroot::build_system_buildroot(const std::string& name)
: build_system_kconfig(name),
  _externals()
{
}

build_system* build_system_buildroot::clone(void) const
{
    return new build_system_buildroot(*this);
}

bool build_system_buildroot::can_build(const std::string& base) const
{
    /* A Config.in next to a Makefile is what buildroot looks like
     * from outside.  The package directory is what tells it from
     * anything else that spelled its Kconfig that way: buildroot is
     * a tree of packages, and one without any isn't buildroot. */
    if (access((base + "Makefile").c_str(), R_OK) != 0)
        return false;
    if (access((base + "Config.in").c_str(), R_OK) != 0)
        return false;

    return access((base + "package/Config.in").c_str(), R_OK) == 0;
}

/* The BR2_EXTERNAL trees, spelled relative to where pconfigure ran.
 * They're written relative to the project that pulled the vendored
 * tree in, the same way a SUBPROJECTS is, since that's the project
 * they belong to. */
namespace {
    std::vector<std::string> based(const context::ptr& ctx,
                                   const std::vector<std::string>& externals)
    {
        auto out = std::vector<std::string>();

        for (const auto& external: externals) {
            auto path = file_utils::normalize_directory(ctx->base + external);

            struct stat buf;
            if (stat(path.c_str(), &buf) != 0 || S_ISDIR(buf.st_mode) == false) {
                std::cerr << "buildroot: '--external " << external << "' names"
                          << " '" << path << "', which isn't a directory\n";
                abort();
            }

            out.push_back(path);
        }

        return out;
    }
}

bool build_system_buildroot::handle_configureopt(const std::string& opt)
{
    auto external = option_value(opt, "--external");
    if (external.size() > 0) {
        _externals.push_back(external);
        return true;
    }

    return build_system_kconfig::handle_configureopt(opt);
}

std::string build_system_buildroot::configureopt_help(void) const
{
    return build_system_kconfig::configureopt_help()
         + "  '--external DIR' adds a BR2_EXTERNAL tree of your own packages\n";
}

kconfig_deps::roots build_system_buildroot::dep_roots(void) const
{
    /* Everything buildroot reads hangs off the Config.in and the
     * Makefile at the top of the tree.  Config.in.legacy is sourced
     * from there like any other, but it's named here anyway because
     * a tree that has one always reads it. */
    auto out = kconfig_deps::roots();
    out.config = {base() + "Config.in", base() + "Config.in.legacy"};
    out.build = {base() + "Makefile"};

    /* An external tree is reached through a variable that names it,
     * so no amount of reading the vendored tree finds it: what it
     * holds has to be named here.  These are the files BR2_EXTERNAL
     * says such a tree is made of. */
    for (const auto& external: based(ctx(), _externals)) {
        out.config.push_back(external + "Config.in");
        out.config.push_back(external + "package/*/Config.in");
        out.build.push_back(external + "external.desc");
        out.build.push_back(external + "external.mk");
        out.build.push_back(external + "package/*/*.mk");
    }

    return out;
}

std::string build_system_buildroot::submake_flags(void) const
{
    auto externals = based(ctx(), _externals);
    if (externals.size() == 0)
        return "";

    /* Buildroot wants these absolutely and separated by colons, and
     * it wants the same list every time: it writes the list into the
     * output directory the first time and complains if a later make
     * disagrees with it. */
    auto out = std::string(" BR2_EXTERNAL=");
    for (size_t i = 0; i < externals.size(); ++i) {
        if (i > 0)
            out += ":";
        out += "$(abspath " + externals[i] + ")";
    }

    return out;
}
