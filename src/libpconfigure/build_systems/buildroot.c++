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
#include "../string_utils.h++"
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

std::vector<std::string> build_system_buildroot::based(void) const
{
    auto out = std::vector<std::string>();

    for (const auto& external: _externals) {
        /* Through the one function that decides what a Configfile is
         * allowed to name.  This used to do its own resolving and ask
         * nothing at all, which made '--external ../ext' a line that
         * came out as 'ext/' when pconfigure ran at the top and as
         * '../ext/' when it ran inside the subproject -- two
         * spellings of BR2_EXTERNAL from one line, and neither of
         * them anchored to the project's prefix variable, so the
         * Makefile the parent includes names whatever directory make
         * happens to be standing beside.
         *
         * 'br2-external' is the shape rather than a directory
         * anybody has: buildroot's own manual calls the tree that,
         * and it is the project's own code, so it sits beside the
         * vendored checkout rather than inside it. */
        auto path = file_utils::normalize_directory(
            checked_project_path("--external", external, "br2-external"));

        struct stat buf;
        if (stat(path.c_str(), &buf) != 0 || S_ISDIR(buf.st_mode) == false) {
            std::cerr << name() << ": '--external " << external << "' names"
                      << " '" << path << "', which isn't a directory\n";
            abort();
        }

        out.push_back(path);
    }

    return out;
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
    for (const auto& external: based()) {
        out.config.push_back(external + "Config.in");
        out.config.push_back(external + "package/*/Config.in");
        out.build.push_back(external + "external.desc");
        out.build.push_back(external + "external.mk");
        out.build.push_back(external + "package/*/*.mk");
    }

    return out;
}

build_system::answers build_system_buildroot::already_answered(void) const
{
    /* kbuild's list first, because buildroot is a kbuild command line
     * with more names on it rather than a different one: the "O=" is
     * the same "O=", a command-line variable reaches every package's
     * own make through MAKEFLAGS, and so a "DESTDIR=" here is the
     * same statement it was there. */
    auto out = build_system_kconfig::already_answered();

    /* And the directories buildroot gives names of its own.  These
     * are the variables its manual writes down as the ones a package
     * -- and therefore anything on the command line above it -- names
     * a directory with: BASE_DIR, BUILD_DIR, PER_PACKAGE_DIR, HOST_DIR,
     * STAGING_DIR, TARGET_DIR, BINARIES_DIR and TOPDIR, plus the
     * BR2_EXTERNAL that submake_flags() already wrote.
     *
     * Every one of them is derived from the "O=" this build system
     * hands the tree, and every one of them is a plain "=" in
     * buildroot's own Makefile -- so a command-line variable of that
     * name replaces it outright and nothing says so.
     *
     * BR2_DL_DIR is deliberately not here.  It is a place buildroot
     * writes that is not inside the object directory, so it looks
     * like one of these; it is the download cache, it holds nothing
     * the build produces, and buildroot's manual tells people to
     * point several builds at one of them on purpose.  A destination
     * is where what was built ends up, and that is the thing this
     * list is about. */
    for (const auto& variable: {"TARGET_DIR", "STAGING_DIR", "HOST_DIR",
                                "BINARIES_DIR"})
        out.destinations.push_back(
            {variable, "says where part of what buildroot builds is"
                       " assembled"});

    /* PER_PACKAGE_DIR sits beside BUILD_DIR rather than beside
     * BR2_DL_DIR: it is buildroot's own per-package build output --
     * "$(BASE_DIR)/per-package/<pkg>" by default -- so unlike the
     * download cache it holds exactly what BUILD_DIR holds, split up
     * one directory per package, and it is derived from "O=" the same
     * way BUILD_DIR is. */
    for (const auto& variable: {"BASE_DIR", "BUILD_DIR", "PER_PACKAGE_DIR"})
        out.directories.push_back(
            {variable, "says where the tree builds"});

    out.directories.push_back(
        {"TOPDIR", "says which tree gets built"});

    /* Buildroot reads its list of external trees once and writes it
     * into the output directory, then refuses a later make that
     * disagrees -- so a second answer here is not a tree built
     * somewhere else, it is a tree that stops building and says the
     * configuration changed.  The list is '--external's to write, and
     * submake_flags() has already put it on this command line. */
    out.directories.push_back(
        {"BR2_EXTERNAL",
         "says which trees of your own packages buildroot reads, which"
         " '--external' has already written onto this command line"});

    return out;
}

std::string build_system_buildroot::submake_flags(void) const
{
    auto externals = based();
    if (externals.size() == 0)
        return "";

    /* Buildroot wants these absolutely and separated by colons, and
     * it wants the same list every time: it writes the list into the
     * output directory the first time and complains if a later make
     * disagrees with it. */
    auto out = std::string("BR2_EXTERNAL=");
    for (size_t i = 0; i < externals.size(); ++i) {
        if (i > 0)
            out += ":";
        out += "$(abspath " + externals[i] + ")";
    }

    /* Quoted whole, name and all, the way makeopt_flags() quotes the
     * variables a --make-var wrote: this is one variable on a make
     * command line like those, and one word is what it has to arrive
     * as.  checked_project_path() has already taken the space and the
     * '$' out of every path in here, so what the quotes are left
     * holding is a ';' in a directory name -- which is a command in a
     * recipe as soon as somebody has a directory of that name.
     *
     * make expands the "$(abspath ...)" before the shell ever reads
     * the line, and path_prefix::rewrite() reads a quote as the end
     * of one word and the start of the next -- so the quotes cost
     * neither the expansion nor the prefix a subproject's copy of
     * this Makefile needs. */
    return " " + string_utils::quoted(out);
}
