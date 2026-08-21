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
 *
 *   --merge-config FILE  Merge a configuration fragment on top of the
 *                        defconfig, before any --configure is set.
 *                        The file is named relative to the project
 *                        that asked for it rather than to the tree,
 *                        since it's that project's statement about
 *                        how it wants somebody else's tree built.
 *
 *   --make-var NAME=VAL  Put a variable on the sub-make's command
 *                        line, where it beats whatever the tree's own
 *                        Makefile has to say about it.
 *
 *   --env NAME=VALUE     Put a variable in the environment the tree
 *                        is built in, where the tree's own Makefile
 *                        is allowed to disagree with it.  Either of
 *                        these reaches the Makefile spelled exactly
 *                        the way it was written, so "$(abspath x)"
 *                        and "$(PATH)" mean what they say.
 *
 *   --target NAME        Ask the tree for a target rather than for
 *                        whatever it builds when it's asked for
 *                        nothing.  May be given more than once, and
 *                        they're asked for one at a time in the order
 *                        they were given.
 *
 *   --depend PATH        Something the build has to wait for, and
 *   --depend-config PATH something the configuration has to wait for.
 *                        Either a file, or another vendored
 *                        subproject of the same project -- which
 *                        means waiting for that tree to be built
 *                        rather than for its directory to change.
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

    /* The configuration fragments to merge on top of the defconfig,
     * in the order they were given, which is the order the tree's own
     * merge program reads them in and therefore the order in which a
     * later one wins. */
    std::vector<std::string> _merges;

    /* Variables to put on the sub-make's command line.  A variable
     * given to make this way beats whatever the tree's own Makefile
     * says, which is the point: it's how you tell somebody else's
     * build system something it never asked to be told. */
    std::vector<std::string> _make_vars;

    /* The environment the vendored build system runs in.  An
     * environment variable and a make command-line variable are not
     * the same thing: the tree's own Makefile is allowed to override
     * this one and isn't allowed to override a --make-var, which is
     * exactly the difference you want for a PATH. */
    std::vector<std::string> _env;

    /* What to ask the vendored tree for.  Empty means whatever its
     * Makefile does when it's run with no target at all, which is
     * what a tree that builds one thing wants and what this did
     * before anybody asked for anything else. */
    std::vector<std::string> _make_targets;

    /* Edges that nothing can be inferred from: a vendored tree says
     * nothing about what it reads outside itself, and one vendored
     * tree says nothing at all about another. */
    std::vector<std::string> _depends;
    std::vector<std::string> _config_depends;

public:
    build_system_kconfig(const std::string& name);
    virtual ~build_system_kconfig(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;
    std::vector<makefile::target::ptr>
    targets(const std::vector<build_system::ptr>& peers) const;
    std::string configure_signature(void) const;

protected:
    void take_configureopt(const std::string& opt);

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
    /* The variables a CONFIGUREOPTS put on the sub-make's command
     * line, with a leading space.  These come after submake_flags(),
     * so a tree that insists on something gets to say it first and
     * the person configuring the build gets the last word -- which is
     * what a make command-line variable means anyway. */
    std::string make_var_flags(void) const;

    /* Runs a command with the environment a CONFIGUREOPTS asked for.
     * These go in front of the whole command rather than after the
     * program's name, which is what makes them environment variables
     * rather than arguments -- and the two mean opposite things to
     * make. */
    std::string with_env(const std::string& command) const;

    /* A file a CONFIGUREOPTS named, spelled relative to where
     * pconfigure ran.  These are written relative to the project that
     * pulled the vendored tree in, the same way a SUBPROJECTS is,
     * since that's the project they belong to. */
    std::string based_file(const std::string& flag,
                           const std::string& path) const;

    /* What one of the --depend paths actually names.  A path that
     * turns out to be another vendored tree in this run becomes that
     * tree's stamp rather than its directory, which is the difference
     * between "wait for it to be built" and "wait for the directory
     * to change" -- and only the first of those is what anybody
     * means. */
    std::string resolve_depend(
        const std::string& flag,
        const std::string& path,
        const std::vector<build_system::ptr>& peers) const;

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

    /* The tree's own program for merging a fragment into a .config.
     * Merging isn't appending: a fragment that sets an option the
     * base file already set has to replace it rather than be read
     * twice, and working out which lines those are is a job for the
     * tree's own program the same way editing one is. */
    virtual std::string merge_config_tool(void) const
        { return base() + "scripts/kconfig/merge_config.sh"; }

    /* TRUE for a tree that builds what it's asked to build with the
     * toolchain it's handed, which is what CROSS_COMPILE means and
     * where everybody else got the spelling from.  A tree that makes
     * its own toolchain before it makes anything with it has no use
     * for the one this project was configured with, and says so. */
    virtual bool wants_cross_compile(void) const
        { return true; }

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

    /* What this run told the tree, which sits beside the stamp
     * rather than inside kbuild_output(): that directory is handed to
     * the vendored tree as its O=, so it's the tree's, and nothing of
     * ours belongs in it. */
    std::string configureopts_file(void) const
        { return output_dir() + "/configure-opts"; }
};

#endif
