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

#ifndef BUILD_SYSTEMS__AUTOTOOLS_HXX
#define BUILD_SYSTEMS__AUTOTOOLS_HXX

#include "../build_system.h++"

/* Autotools: a "./configure" that writes a Makefile, and then a make
 * that reads it.  Autoconf, automake and libtool have been spelled a
 * dozen different ways over thirty years, but the part anybody
 * outside the tree has to know has never changed -- run configure,
 * run make, run make install -- which is the whole of what this
 * drives.
 *
 * A SUBPROJECTS gets built this way when the directory it names has a
 * "configure" in it, or a "configure.ac" (or the older
 * "configure.in") that one can be made out of.  Those are the two
 * states such a tree shows up in and they want different things done
 * to them: a release tarball ships a generated configure and is ready
 * to be run, while a checkout of the same project usually doesn't,
 * because a generated file in version control is a merge conflict
 * waiting to happen.  A tree of the second kind has its configure
 * made first, by whichever program it wants run -- see --autoreconf
 * below.
 *
 * Out-of-tree is the only way a tree gets built here.  configure
 * works out where its sources are from the path it was run as, so the
 * build directory is made in this project's object directory, and
 * "$(abspath tree)/configure" is run from inside it.  That is what
 * keeps the promise every vendored build system in pconfigure makes:
 * the tree is somebody else's, and a "make distclean" leaves it
 * exactly as it was found.
 *
 * There is no in-tree fallback, and that is a decision rather than an
 * omission.  A tree that can't do VPATH can only be built by
 * scattering objects, Makefiles and a config.status through somebody
 * else's checkout, and pconfigure would then have no way to take them
 * back out again: "make clean" would have to run the tree's own
 * distclean, which is that tree's opinion about what it owns rather
 * than ours, and anything it missed would be left for the next build
 * to trip over.  Two projects vendoring one such tree with different
 * options would also quietly overwrite each other's builds, since
 * there would be one build directory for the two of them.  A tree
 * that really can't be built out of tree wants a copy of its own,
 * which is a thing the project vendoring it can arrange and a thing
 * this can't.
 *
 * The one exception, which cannot be designed away, is the generated
 * configure: autoconf has no out-of-tree mode and writes "configure"
 * next to the "configure.ac" it was made from.  A tree that ships no
 * configure has already decided that, and its .gitignore usually says
 * so.  Nothing else this writes goes anywhere near the tree.
 *
 * That rule touches the configure once the bootstrap has run, which
 * is the same file said to be newer rather than a second thing
 * written into the tree.  It has to: autoreconf rewrites configure
 * only when configure.ac or aclocal.m4 is newer than it, so a tree
 * whose Makefile.am was edited gets a new Makefile.in and a
 * configure with the mtime it always had -- older than the
 * Makefile.am this rule waits on, which would make the rule fire
 * again on the next make, and the next, forever.
 *
 * Four rules come out of this, and the first of them only for a tree
 * that needs it:
 *
 *   - the tree's own "configure", made by autoconf or by whatever the
 *     tree wants run instead;
 *
 *   - the build directory's "config.status", which is what configure
 *     leaves behind to say it ran and what the tree's own Makefiles
 *     hang their remaking off;
 *
 *   - a stamp that says the tree has been built -- and installed,
 *     since here that is part of building it: a vendored tool tree is
 *     vendored so that the rest of this build can run the tool, and
 *     the rest of this build happens during "make" rather than during
 *     "make install";
 *
 *   - and one rule per SUBPROJECT_TARGETS, which build_system adds.
 *
 * What gets installed goes into --prefix, which defaults to a
 * directory inside this project's object directory rather than to
 * the project's own PREFIX.  That default is the careful one: the
 * install runs during "make", so a prefix of "/usr/local" would mean
 * a plain "make" writing into /usr/local, which is not a thing any
 * build should do without being asked twice.  A project that wants
 * several vendored trees to land in one directory -- which is the
 * usual reason to want this at all, since a toolchain is found by
 * looking one "bin" up -- says so with --prefix.
 *
 * Where that prefix is allowed to point, and what the cleaning
 * targets do with it once it is there, is not this build system's
 * question: every vendored build system here has the same one, and it
 * is answered once in build_system::install_dir() and
 * build_system::checked_install_dir().  The short of it is that an
 * install prefix is a directory inside the object directory of the
 * project that vendored the tree -- so "make distclean" removes it
 * along with everything else in there, and "make cache-clean" is told
 * to leave it alone, since no rule in the Makefile builds what an
 * install put there and cache-clean cannot tell that from stale.
 *
 * What this deliberately does not do is translate CROSS_COMPILE into
 * an autoconf --host.  A CROSS_COMPILE is a program-name prefix, and
 * an autoconf host is a triple; the two look alike for the usual
 * toolchain and stop looking alike the moment the prefix is a path,
 * or names a compiler autoconf would have called something else.  A
 * tree that has to be told which machine it builds for is told with
 * '--configure-flag --host=...', which says one thing once.
 *
 * The options a CONFIGUREOPTS gives this are:
 *
 *   --prefix DIR         Where the tree installs to, named relative
 *                        to the project that asked for it the same
 *                        way a SUBPROJECTS is.  Defaults to a
 *                        "prefix" directory beside the build.  It
 *                        reaches configure absolutely, because
 *                        autotools bakes a prefix into what it
 *                        builds.  Any directory inside that project's
 *                        object directory, like "obj/toolchain": see
 *                        build_system::install_dir() for why that is
 *                        the rule and
 *                        build_system::checked_install_dir() for
 *                        where it is enforced.
 *
 *   --configure-flag ARG One argument for ./configure, passed on
 *                        exactly as written: '--configure-flag
 *                        --enable-foo'.  One option is one argument,
 *                        however many spaces are in it, so
 *                        '--configure-flag --with-solver=z3 --in'
 *                        asks for a solver whose name has a space in
 *                        it rather than for two things.
 *
 *   --configure-var N=V  A variable on ./configure's command line,
 *                        which is how autoconf is told to use a
 *                        program it would otherwise have gone looking
 *                        for: '--configure-var YACC=/opt/bin/bison'.
 *                        Spelled apart from the flags because a word
 *                        without an '=' in it is one of those and not
 *                        one of these, and the two go wrong in
 *                        different ways.
 *
 *   --env NAME=VALUE     Put a variable in the environment the tree
 *                        is bootstrapped, configured, built and
 *                        installed in.  Either this or a
 *                        --configure-var reaches the Makefile spelled
 *                        exactly the way it was written, so
 *                        "$(abspath x)" and "$(PATH)" mean what they
 *                        say.  The value is one word however many
 *                        spaces are in it -- '--env CFLAGS=-O2 -g'
 *                        is one variable with two flags in it -- and
 *                        the name is not quoted, since a quoted
 *                        NAME=VALUE stops being an assignment and
 *                        becomes a program to run.
 *
 *   --make-var NAME=VAL  Put a variable on the command line of the
 *                        make that builds and installs the tree,
 *                        where it beats whatever the tree's own
 *                        Makefile has to say about it.  This is the
 *                        same thing a MAKEOPS says, spelled the way
 *                        the options are; the two share one list and
 *                        one order.
 *
 *   --target NAME        Ask the tree for a target rather than for
 *                        whatever it builds when it's asked for
 *                        nothing.  May be given more than once, and
 *                        they're asked for one at a time in the order
 *                        they were given -- so one option is one
 *                        target, however many spaces or semicolons
 *                        are in it, and a tree that wants two of them
 *                        is asked twice.
 *
 *   --install            Run "make install" after the build, which is
 *   --no-install         what happens unless it's turned off.  What a
 *                        SUBPROJECT_TARGETS names is relative to
 *                        whichever of the two directories the tree
 *                        last wrote into: the prefix when it
 *                        installs, and the build directory when it
 *                        doesn't.
 *
 *   --autoreconf CMD     What to run inside the tree to make its
 *                        "configure", when it hasn't got one.  The
 *                        default is worked out by looking: an
 *                        executable "autogen.sh" or "bootstrap" is
 *                        what a tree that has one wants run, a tree
 *                        with automake or its own m4 wants
 *                        "autoreconf -i", and anything else wants
 *                        plain "autoconf".  Guessing is worth it
 *                        because the guess is right for almost every
 *                        tree and the cost of it being wrong is one
 *                        option.
 *
 *   --no-autoreconf      Don't make one, because the tree ships one
 *                        and the machine doing the building has no
 *                        autoconf on it.  A tree that then turns out
 *                        to have no configure is an error rather than
 *                        a build that gets halfway.  This and
 *                        '--autoreconf CMD' are one setting said two
 *                        ways, so the last one written wins: a
 *                        '--no-autoreconf' under a BUILD_SYSTEMS is
 *                        undone for the one tree that needs
 *                        bootstrapping by an '--autoreconf' under its
 *                        SUBPROJECTS, which is the reason to write
 *                        either of them twice.
 *
 *   --depend PATH        Something this tree has to wait for: either
 *                        a file, or another vendored subproject of
 *                        the same project -- which means waiting for
 *                        that tree to be built rather than for its
 *                        directory to change.  It's waited for by the
 *                        configure as well as by the build, since
 *                        configure runs the compiler to find out what
 *                        it can do.
 *
 * Four of those hand a word of a Configfile to the tree: the flags,
 * the variables on configure's command line, the variables on the
 * installing make's command line, and the environment that make
 * imports variables from in the first place.  A word that says where
 * the tree installs, or which tree is being configured, is refused
 * from all four -- see build_system::refuse_second_answer(), which is
 * where every one of them asks and what already_answered() below
 * hands the names to.  The one place either of those is said is the
 * SUBPROJECTS and the --prefix, which is where the rest of the build
 * can read the answer.
 *
 * Refused from all four rather than from three, which is what this
 * used to do: DESTDIR was turned away as a --configure-var, as a
 * --make-var and as a MAKEOPS, and taken as an --env -- and the
 * install went wherever it pointed on a plain "make".  Three closed
 * doors and an open one is worse than four open ones, because the
 * three are what somebody reads as the rule.
 */
class build_system_autotools: public build_system {
private:
    /* Where the tree installs to, exactly as the option wrote it:
     * resolving it needs the project this was bound to, and an
     * unbound build system -- which is what a CONFIGUREOPTS under a
     * BUILD_SYSTEMS lands on -- hasn't got one yet. */
    std::string _prefix;

    /* Everything that goes on ./configure's command line, flags and
     * variables together, in the order they were written.  One list
     * because that's one command line: autoconf doesn't care which
     * order it's told things in, and a reader of the Configfile does.
     * They're told apart when they come in, which is where the
     * difference is worth anything, and not afterwards. */
    std::vector<std::string> _configure_args;

    /* The environment the vendored build system runs in.  An
     * environment variable and a configure variable are not the same
     * thing: configure records what it was handed on its command line
     * into config.status and uses it again on a rerun, while
     * something out of the environment is only true for the run that
     * saw it.  That difference is exactly why both exist. */
    std::vector<std::string> _env;

    /* What to ask the vendored tree for.  Empty means whatever its
     * Makefile does when it's run with no target at all, which for an
     * automake tree is "all". */
    std::vector<std::string> _make_targets;

    /* Edges that nothing can be inferred from: a vendored tree says
     * nothing about what it reads outside itself, and one vendored
     * tree says nothing at all about another. */
    std::vector<std::string> _depends;

    /* TRUE when "make install" is part of building this tree, which
     * it is unless somebody said otherwise. */
    bool _install;

    /* What to run to make the tree's "configure", and whether to make
     * one at all.  Empty means "work it out by looking at the tree",
     * which is what almost every tree wants.
     *
     * Two fields, one setting: the option that writes either of them
     * clears the other, so they are never both in force and which
     * one gets asked about first decides nothing.  That's what makes
     * '--autoreconf' and '--no-autoreconf' last-one-wins, the way
     * '--install' and '--no-install' are by writing one field
     * between them. */
    std::string _autoreconf;
    bool _no_autoreconf;

public:
    build_system_autotools(const std::string& name);
    virtual ~build_system_autotools(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;
    std::string configure_signature(void) const;

    /* Where the tree was told to put its output, which is a directory
     * of ours that gets handed over rather than anything inside the
     * tree.  Everything of ours -- the stamp, the options this run was
     * given -- stays in output_dir() beside it, since this one is the
     * tree's. */
    std::string build_output(void) const
        { return output_dir() + "/build"; }

    /* Where the tree installs to.  This resolves the --prefix against
     * the project that vendored the tree, so it is only safe to ask
     * once this has been bound to a subproject, and it aborts on the
     * prefixes build_system::checked_install_dir() refuses -- which
     * is everything that is not a directory inside that project's
     * object directory. */
    std::string install_prefix(void) const;

    /* The same directory, or "" for a tree told not to install,
     * which is the shape the cleaning targets want: see
     * build_system::install_dir(). */
    std::string install_dir(void) const;

    /* TRUE when the prefix is the one this build system picked for
     * itself rather than one a Configfile wrote down, which is what
     * decides whether the rules below are allowed to delete it.
     *
     * A default prefix is a directory of this tree's own, inside its
     * own output directory, that nothing else in the build ever writes
     * into -- so emptying it costs one reinstall and is nobody else's
     * business.  A --prefix is written down precisely because several
     * trees are meant to land in one directory, and the files in there
     * belong to whichever tree installed them; a tree that emptied it
     * on its way past would be deleting a peer's install, and nothing
     * would put that back, because the peer's stamp still says it has
     * been built.
     *
     * The same predicate under the same name is what cmake's build
     * system asks before doing the same two things, since it is the
     * same question about the same kind of directory. */
    bool private_prefix(void) const { return _prefix.size() == 0; }

    /* Which of those two a SUBPROJECT_TARGETS names things relative
     * to, which is wherever the tree last wrote something: a build
     * directory is full of objects and libtool wrappers whose layout
     * is nobody's business but the tree's, while the installed
     * layout -- bin, lib, include -- is the one thing an autotools
     * tree really does promise. */
    std::string build_dir(void) const
        { return _install ? install_prefix() : build_output(); }

    /* What configure leaves behind to say it ran.  Every autotools
     * tree writes this one, which is more than can be said for the
     * Makefiles: which of those exist depends on what the tree's
     * AC_CONFIG_FILES asked for. */
    std::string config_status(void) const
        { return build_output() + "/config.status"; }

    std::string build_stamp(void) const
        { return output_dir() + "/build-stamp"; }

    /* What this run told the tree, which sits beside the build
     * directory rather than inside it: that directory is handed to
     * the vendored tree, so it's the tree's, and nothing of ours
     * belongs in it. */
    std::string configureopts_file(void) const
        { return output_dir() + "/configure-opts"; }

protected:
    std::vector<makefile::target::ptr>
    vendored_targets(const std::vector<build_system::ptr>& peers,
                     const std::string& project_base) const;
    void take_configureopt(const std::string& opt);
    void take_makeopt(const std::string& opt);

    /* What a generated configure, and the make that installs what it
     * built, read as a second answer to something this build system
     * has already said: where the tree installs, where each kind of
     * file goes under that, and which tree is being configured.
     *
     * Only the names are here.  What a word has to look like to be
     * one of them, what happens when it is, and what the diagnostic
     * says are build_system::refuse_second_answer()'s, which is what
     * every option below calls and the only thing that refuses any of
     * this -- the names are the tree's rather than pconfigure's
     * ("bindir" here, "CMAKE_INSTALL_BINDIR" one file over), and
     * nothing else about the question differs between them. */
    answers already_answered(void) const;

    /* Takes one CONFIGUREOPTS, and answers whether it was one of
     * these.  Split out from take_configureopt() the way kconfig
     * splits it, so that a tree with options of its own can be bolted
     * on later without the spelling of "--prefix" moving. */
    virtual bool handle_configureopt(const std::string& opt);

    /* What to print when nobody recognized an option, which is the
     * list of the ones that would have been recognized. */
    virtual std::string configureopt_help(void) const;


    /* What to run inside the tree to make its "configure", or "" for
     * a tree that ships one and doesn't need it made.  Looks at the
     * tree, so this needs a bound build system. */
    std::string bootstrap_command(void) const;

    /* Runs a command with the environment a CONFIGUREOPTS asked for.
     * These go in front of the whole command rather than after the
     * program's name, which is what makes them environment variables
     * rather than arguments. */
    std::string with_env(const std::string& command) const;

    /* Everything a CONFIGUREOPTS asked to be on ./configure's command
     * line, with a leading space, each one quoted as the single
     * argument it is. */
    std::string configure_args(void) const;
};

#endif
