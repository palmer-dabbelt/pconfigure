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

#ifndef BUILD_SYSTEMS__MESON_HXX
#define BUILD_SYSTEMS__MESON_HXX

#include "../build_system.h++"

/* Meson: a "meson.build" that a "meson setup" turns into a ninja
 * build directory, which ninja then builds.
 *
 * A SUBPROJECTS gets built this way when the directory it names has a
 * meson.build in it.  That is the whole of what a meson project looks
 * like from outside, and like cmake's CMakeLists.txt it is a file
 * plenty of trees ship beside some other build system's -- which of
 * the two claims such a tree is the BUILD_SYSTEMS order's to say, the
 * same as it is everywhere else.
 *
 * Almost everything about how this drives a tree is the answer cmake
 * already gave, for the same reasons, and the reasons are written out
 * once in cmake.h++ rather than twice: out of tree always, with the
 * build directory inside this build system's own output directory;
 * configuring is starting over, because a meson build directory
 * remembers a "-D" that has since been deleted from the Configfile
 * exactly the way a cmake cache does; the configure-side and
 * build-side options are written into two files, so that adding a
 * --target is not a rebuild from nothing, and the second of them is
 * written by make out of the recipe that reads it; the default prefix
 * is inside the output directory and is taken by a configure and a
 * "make clean", while one a --prefix named is left alone.  What
 * follows is only where meson differs.
 *
 * The configure rule hangs off the build directory's build.ninja.
 * meson writes it last, after everything else a setup decided, and a
 * setup that fails leaves the directory behind without one -- so,
 * like cmake's CMakeCache.txt, it is a real file the tree writes that
 * says the configure finished, rather than a stamp of ours that says
 * a command was started.  An edit to a meson.build is not a reason to
 * configure again, for the same reason an edit to a CMakeLists.txt
 * isn't: build.ninja knows how to re-run meson itself when one of
 * meson's inputs changes, so the build rule re-entering the tree
 * picks it up for the price of a regenerate.
 *
 * The build is "ninja -C" rather than "meson compile -C", and the
 * install is the build directory's own "install" target rather than
 * "meson install".  Both meson commands are wrappers that find the
 * build directory's ninja and run it, which would be a distinction
 * without a difference except for which meson does the wrapping: the
 * "meson" on the PATH of the make that runs the build is not
 * necessarily the meson that set the tree up, and a meson handed a
 * build directory that a different version of it wrote refuses to
 * touch it.  build.ninja records the meson that set it up by its
 * absolute path and calls that one for the regenerate and the
 * install, so asking ninja is how every step after the setup runs
 * under the meson that did the setup, whatever the PATH happens to
 * say by the time the build runs.  A tree whose own --setup-script
 * does the setup -- see below -- may well run a meson it brought with
 * it, which is where that stops being a nicety: QEMU's configure
 * builds a Python venv and installs its own meson into it.
 *
 * ninja is also what decides how parallel the build is, which is the
 * other thing that would otherwise want a recursive make here.  A
 * ninja new enough to be a jobserver client (1.13 onwards) takes its
 * jobs from the make that ran it when it is given no "-j" of its own,
 * so a "make -j8" is eight jobs in total and there is nothing for
 * this build system to do about it but stay out of the way.  An older
 * ninja runs as many as it likes, which is what it would do anyway
 * and what --jobs is for.  The recipe deliberately has no leading
 * '+': a GNU make that passes its jobserver through a fifo hands it
 * to every recipe whether or not it is marked, and the '+' would also
 * mean running the build under a "make -n" that was asked only to
 * print what a build would do.
 *
 * There is no make in any of this, so there is nothing for a MAKEOPS
 * to go on the command line of, and build_system refuses one: see
 * run_by_make().  What a tree would take as a variable it takes here
 * as an option, which is --define.
 *
 * The options a CONFIGUREOPTS gives this are:
 *
 *   --build-type NAME    meson's "buildtype", which is asked for often
 *                        enough to be worth a name of its own:
 *                        '--build-type release'.  It reaches the tree
 *                        as "-Dbuildtype=NAME", which meson reads
 *                        the same as its "--buildtype" and which,
 *                        being a "-D" like any other, is the spelling
 *                        anything that wraps meson is most likely to
 *                        pass through unchanged.  Saying nothing
 *                        leaves the tree with whatever its project()
 *                        defaults to.
 *
 *   --define NAME=VALUE  A build option, reaching meson as
 *                        '-DNAME=VALUE' and as one argument however
 *                        many spaces or commas are in it, since an
 *                        array option is written with both.
 *
 *   --prefix DIR         Where the tree installs to, named relative
 *                        to the project that asked for it the same
 *                        way a SUBPROJECTS is, and reaching meson
 *                        absolutely.  Defaults to a "prefix"
 *                        directory beside the build.  Any directory
 *                        inside that project's object directory: see
 *                        build_system::install_dir() for why that is
 *                        the rule and build_system::checked_install_dir()
 *                        for where it is enforced.
 *
 *   --configure-arg ARG  One more argument for the "meson setup" that
 *                        configures the tree, or for the --setup-script
 *                        that runs in its place, passed on exactly as
 *                        written and split by the shell:
 *                        '--configure-arg --wrap-mode=nofallback'.
 *                        This is the way out for anything the options
 *                        above don't cover, and for a setup script's
 *                        own options, which meson has never heard of.
 *
 *   --setup-script PATH  A script inside the tree that sets the tree
 *                        up instead of a "meson setup": for a tree
 *                        whose meson.build reads files only its own
 *                        script writes.  QEMU is one -- its
 *                        meson.build loads a config-host.mak out of
 *                        the build directory, its configure is what
 *                        writes that and then runs "meson setup"
 *                        itself, and a bare "meson setup" fails at
 *                        the first line that wants the file.  The
 *                        script is run from inside the build
 *                        directory, which is how a configure of that
 *                        kind is told where to build, by its absolute
 *                        path, which is how it finds its sources, and
 *                        with the arguments "meson setup" would have
 *                        been handed bar the two directories -- a
 *                        "--prefix=", a "-D" per option -- since a
 *                        script that wraps meson has to take at least
 *                        those.  It has to leave a meson build
 *                        directory behind, build.ninja and all, since
 *                        everything after it is ninja's.  A
 *                        --configure-arg that names a relative path is
 *                        relative to the build directory here.
 *
 *   --target NAME        Ask ninja for a target rather than for its
 *                        default.  May be given more than once, and
 *                        they're asked for one at a time in the order
 *                        they were given.
 *
 *   --jobs N             How many jobs ninja runs at once.  Leave it
 *                        off to have a new enough ninja share make's
 *                        jobserver instead.
 *
 *   --install            Run the build directory's install target
 *   --no-install         after building, which is what happens unless
 *                        it's turned off.  A SUBPROJECT_TARGETS names
 *                        a file in the prefix when the tree installs
 *                        and in the build directory when it doesn't.
 *
 *   --env NAME=VALUE     Put a variable in the environment the tree is
 *                        set up, built and installed in.
 *
 *   --depend PATH        Something the build has to wait for, and
 *   --depend-config PATH something the configuration has to wait for,
 *                        exactly as cmake's are.  A --depend is waited
 *                        for by both, since meson runs the compiler
 *                        while it is deciding what the tree can do.
 *
 * A --define, a --configure-arg and an --env each hand a word of a
 * Configfile to meson, or to the script that runs in its place, and a
 * word that says where the tree installs is refused from all
 * three: see already_answered() for the names and
 * build_system::refuse_second_answer() for the rest.
 */
class build_system_meson: public build_system {
private:
    /* meson's "buildtype", or empty to say nothing about it. */
    std::string _build_type;

    /* The build options, in the order they were written, since a
     * later "-D" of the same name is the one meson keeps. */
    std::vector<std::string> _defines;

    /* Everything else this run puts on the setup's command line, in
     * the order it was written. */
    std::vector<std::string> _configure_args;

    /* The tree's own script that sets it up, relative to the top of
     * the tree, or empty for a plain "meson setup". */
    std::string _setup_script;

    /* Where the tree installs to, exactly as the option wrote it:
     * resolving it needs the project this was bound to, and an
     * unbound build system hasn't got one yet. */
    std::string _prefix;

    /* TRUE when the install target is part of building the tree. */
    bool _install;

    /* What to ask ninja for.  Empty means its default, which for a
     * meson build directory is "all". */
    std::vector<std::string> _ninja_targets;

    /* How many jobs ninja runs at once, or empty for a ninja that
     * wasn't told.  Digits or it never got past take_configureopt(). */
    std::string _jobs;

    /* The environment the setup, the build and the install run in. */
    std::vector<std::string> _env;

    /* Edges that nothing can be inferred from. */
    std::vector<std::string> _depends;
    std::vector<std::string> _config_depends;

    /* Every CONFIGUREOPTS line this was handed, split by which of the
     * two rules reads it, the same way cmake splits them and for the
     * same reason: a changed configure-side option throws the build
     * directory away, and a changed build-side one is one more ninja
     * in a tree that is already built. */
    std::vector<std::string> _configure_lines;
    std::vector<std::string> _build_lines;

public:
    build_system_meson(const std::string& name);
    virtual ~build_system_meson(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;
    std::string configure_signature(void) const;

    /* Where meson is told to put its output.  It is meson's, and is
     * removed whole every time the tree is configured, so everything
     * of ours stays in output_dir() beside it. */
    std::string meson_build_dir(void) const
        { return output_dir() + "/build"; }

    /* What a finished setup leaves behind in that directory, and the
     * file the configure rule hangs off.  See the header. */
    std::string ninja_file(void) const
        { return meson_build_dir() + "/build.ninja"; }

    /* Where the tree installs to, resolved against the project that
     * vendored it.  Only safe to ask once this is bound. */
    std::string install_prefix(void) const;

    /* The same directory, or "" for a tree told not to install: see
     * build_system::install_dir(). */
    std::string install_dir(void) const;

    /* TRUE when nobody wrote a --prefix, which is most of what
     * decides which cleaning targets may delete the prefix: see
     * build_system_cmake::private_prefix(), which is the same
     * question. */
    bool private_prefix(void) const { return _prefix.size() == 0; }

    /* Which directory a SUBPROJECT_TARGETS is named from. */
    std::string build_dir(void) const;

    std::string build_stamp(void) const
        { return output_dir() + "/build-stamp"; }

    /* The configure-side options, written by pconfigure after the
     * Makefile, and the build-side ones, written by make out of the
     * recipe that reads them.  See cmake.h++ for why those are the
     * only two writers that are safe. */
    std::string configureopts_file(void) const
        { return output_dir() + "/configure-opts"; }
    std::string buildopts_file(void) const
        { return output_dir() + "/build-opts"; }
    std::string build_signature(void) const;

    /* Never a file, so the rule that writes buildopts_file() is asked
     * on every make. */
    std::string buildopts_force(void) const
        { return buildopts_file() + "-force"; }

protected:
    std::vector<makefile::target::ptr>
    vendored_targets(const std::vector<build_system::ptr>& peers,
                     const std::string& project_base) const;
    void take_configureopt(const std::string& opt);

    /* FALSE, always: nothing here is a make.  build_system reads this
     * to refuse a MAKEOPS where it is written. */
    bool run_by_make(void) const { return false; }

    /* What meson, and a setup script in its place, reads as a second
     * answer to where the tree installs.  The names only; the
     * refusing is build_system::refuse_second_answer()'s. */
    answers already_answered(void) const;

    /* Runs a command with the environment a CONFIGUREOPTS asked for,
     * in front of the whole command so that each is an environment
     * variable rather than an argument. */
    std::string with_env(const std::string& command) const;

    /* What to run to build one ninja target, or the default one when
     * the target is empty. */
    std::string build_command(const std::string& target) const;

    /* What to print when nobody recognized an option. */
    std::string configureopt_help(void) const;
};

#endif
