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

#ifndef BUILD_SYSTEMS__KCONFIG_HXX
#define BUILD_SYSTEMS__KCONFIG_HXX

#include "../build_system.h++"

/* Linux's build system, and everything else that copied it: a
 * configuration that comes out of Kconfig, and a build that comes out
 * of Makefiles that read that configuration.
 *
 * A SUBPROJECTS gets built this way when the directory it names has a
 * Kconfig in it alongside something for make to read, which is what a
 * kbuild tree looks like from outside and doesn't ask the tree to
 * know anything about pconfigure.
 *
 * Two rules come out of this, both of which run at make time.  The
 * first turns a defconfig and a list of options into a .config, and
 * the second hands the whole build over to the vendored tree's own
 * make.  Neither of them is where the interesting part is: what makes
 * this work is the list of files those rules depend on, which is
 * guessed at configure time so that make has something to compare
 * against before it recurses.
 *
 * The options a CONFIGUREOPTS gives this are:
 *
 *   --defconfig NAME     The make target that produces the starting
 *                        configuration.  Defaults to "defconfig".
 *
 *   --configure OPT=y    Set an option on top of that defconfig.
 *   --configure OPT=m    "y", "m" and "n" mean what they mean in a
 *   --configure OPT=n    .config; anything else is used as a value.
 *                        Later ones win, so the order matters.
 */
class build_system_kconfig: public build_system {
private:
    /* The make target that writes the first .config.  This is a
     * target rather than a file because that's how kbuild spells it:
     * "make x86_64_defconfig", not "cp arch/x86/configs/...". */
    std::string _defconfig;

    /* One option that gets set on top of the defconfig. */
    struct option {
        std::string name;
        std::string value;

        option(const std::string& name, const std::string& value)
        : name(name), value(value)
        {}
    };

    /* In the order they were given, since a later one is allowed to
     * overwrite an earlier one. */
    std::vector<option> _options;

public:
    build_system_kconfig(const std::string& name);
    virtual ~build_system_kconfig(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;
    void add_configureopt(const std::string& opt);
    std::vector<makefile::target::ptr> targets(void) const;

public:
    /* Where the vendored build system is told to put its output.
     * kbuild wants this named absolutely, which is make's job rather
     * than ours -- see targets(). */
    std::string kbuild_output(void) const
        { return output_dir() + "/build"; }

    /* The configuration this run asked for, and the stamp that says
     * the vendored build has been run since anything it reads
     * changed. */
    std::string config_file(void) const
        { return kbuild_output() + "/.config"; }
    std::string build_stamp(void) const
        { return output_dir() + "/build-stamp"; }
};

#endif
