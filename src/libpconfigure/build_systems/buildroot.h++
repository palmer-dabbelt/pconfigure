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

#ifndef BUILD_SYSTEMS__BUILDROOT_HXX
#define BUILD_SYSTEMS__BUILDROOT_HXX

#include "kconfig.h++"

/* Buildroot, which builds a whole embedded Linux system out of a
 * kconfig-derived tree.  It took Kconfig and the shape of kbuild's
 * command line from Linux and then spelled almost everything else
 * differently, so it's the kconfig build system with the names
 * changed:
 *
 *   - the top of the configuration is a "Config.in" rather than a
 *     "Kconfig", which is also how a SUBPROJECTS is recognized as one
 *     of these;
 *
 *   - the program that edits a .config is "utils/config" rather than
 *     "scripts/config";
 *
 *   - the build description is in ".mk" files that the top-level
 *     Makefile pulls in by wildcard, one per package;
 *
 *   - a tree of your own packages is bolted on from outside with
 *     BR2_EXTERNAL rather than being sourced from within.
 *
 * The rest -- an out-of-tree build with O=, a defconfig target, an
 * olddefconfig after the options are set, and a dependency guess that
 * the recursive make hangs off -- is what build_system_kconfig
 * already does.
 *
 * The options a CONFIGUREOPTS gives this are the kconfig ones, plus:
 *
 *   --external DIR       A BR2_EXTERNAL tree, holding packages and
 *                        defconfigs of your own.  May be given more
 *                        than once; buildroot takes them in order.
 */
class build_system_buildroot: public build_system_kconfig {
private:
    /* The BR2_EXTERNAL trees, in the order they were given, since
     * that's the order buildroot searches them in.  These are named
     * relative to where pconfigure ran rather than relative to the
     * vendored tree: an external tree is the vendoring project's own
     * code, so it lives on this side of the fence. */
    std::vector<std::string> _externals;

public:
    build_system_buildroot(const std::string& name);
    virtual ~build_system_buildroot(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;

protected:
    /* Virtual methods from build_system_kconfig. */
    bool handle_configureopt(const std::string& opt);
    std::string configureopt_help(void) const;
    kconfig_deps::roots dep_roots(void) const;
    std::string submake_flags(void) const;

    std::string config_tool(void) const
        { return base() + "utils/config"; }
};

#endif
