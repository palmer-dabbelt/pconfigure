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
#include "kconfig_deps.h++"

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
 * This is also what every other kconfig-derived build system is built
 * out of, since the trees that copied kbuild copied the shape of all
 * of this along with it.  What such a tree gets to say for itself is
 * which files it's recognized by, which files a chase starts from,
 * what its .config editor is called, and what it wants on the
 * sub-make's command line -- everything else is here.
 *
 * The options a CONFIGUREOPTS gives this are:
 *
 *   --defconfig NAME     The make target that produces the starting
 *                        configuration.  Defaults to "defconfig".
 *
 *   --configure OPT=y    Set an option on top of that defconfig.
 *   --configure OPT=m    "y", "m" and "n" mean what they mean in a
 *   --configure OPT=n    .config, a quoted value is a string, and
 *   --configure OPT="s"  anything else is used as a value.  Later
 *                        ones win, so the order matters.
 */
class build_system_kconfig: public build_system {
protected:
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

protected:
    /* Takes one CONFIGUREOPTS, and answers whether it was one of
     * these.  A tree with options of its own overrides this, handles
     * what it knows, and hands the rest back here -- which is what
     * keeps "--defconfig" spelled the same way everywhere. */
    virtual bool handle_configureopt(const std::string& opt);

    /* What to print when nobody recognized an option, which is the
     * list of the ones that would have been recognized. */
    virtual std::string configureopt_help(void) const;

    /* The value a flag was given, or "" when this option isn't that
     * flag.  Both "--flag value" and "--flag=value" turn up in the
     * wild and neither is any harder to read than the other. */
    static std::string option_value(const std::string& opt,
                                    const std::string& flag);

protected:
    /* The files the dependency guess starts from, which is most of
     * what tells one of these trees from another. */
    virtual kconfig_deps::roots dep_roots(void) const;

    /* The tree's own program for setting an option in a .config.  A
     * .config isn't a list of settings, it's the answer Kconfig
     * worked out, so editing one is a job for the tree rather than
     * for us. */
    virtual std::string config_tool(void) const
        { return base() + "scripts/config"; }

    /* Anything else the vendored make wants on its command line,
     * with a leading space.  Empty for kbuild, which is told
     * everything it needs to know by O= and the .config. */
    virtual std::string submake_flags(void) const
        { return ""; }

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
