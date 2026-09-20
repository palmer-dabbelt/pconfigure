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

#ifndef BUILD_SYSTEMS__CMAKE_HXX
#define BUILD_SYSTEMS__CMAKE_HXX

#include "../build_system.h++"

/* CMake: a "CMakeLists.txt" that a cmake run turns into a build
 * system of some other kind, which is then what actually builds the
 * tree.
 *
 * A SUBPROJECTS gets built this way when the directory it names has a
 * CMakeLists.txt in it, which is the whole of what a cmake tree looks
 * like from outside.  A tree whose CMakeLists.txt is one directory
 * down -- llvm-project, whose top level holds nothing but the
 * subprojects -- is named all the way down in the SUBPROJECTS, since
 * which build system builds a directory is decided by looking in it
 * and that happens before a single CONFIGUREOPTS has been read.  A
 * tree with both a CMakeLists.txt and a configure.ac is claimed by
 * whichever of the two build systems its BUILD_SYSTEMS named first:
 * that is what the ordering is for, and it is the only thing that can
 * say which of two real answers was meant.
 *
 * Out-of-tree is the only way a tree gets built here, which cmake
 * makes easy: "-S" says where the sources are, "-B" says where the
 * output goes, and neither the tree nor its CMakeLists.txt has to
 * know.  So a "make distclean" leaves the vendored tree exactly as it
 * was found, and nothing this writes goes anywhere near it.
 *
 * Three rules come out of this:
 *
 *   - the build directory's CMakeCache.txt, which is what cmake
 *     leaves behind to say it has configured this tree and what it
 *     reads back to find out what it was configured with;
 *
 *   - a stamp that says the tree has been built -- and installed,
 *     since here that is part of building it: a vendored tool tree is
 *     vendored so the rest of this build can run the tool, and the
 *     rest of this build happens during "make" rather than during
 *     "make install";
 *
 *   - the build-side options the stamp's recipe was written out of,
 *     which make writes down so that a later make can tell that they
 *     have moved.  Why that one is make's to write and not
 *     pconfigure's is further down.
 *
 * Plus one rule per SUBPROJECT_TARGETS, which build_system adds.
 *
 * Configuring is starting over, and that is the one thing about this
 * build system worth reading twice.  A cmake cache remembers a -D
 * that has been deleted from the Configfile, forever, and it refuses
 * outright to be reconfigured with a generator other than the one it
 * was made with -- so "re-run cmake in the directory that's there" is
 * not a way of getting what the Configfile now says.  The configure
 * rule therefore removes the build directory and starts again, and
 * its only prerequisites are the things for which starting again is
 * the right answer: the file this run's configure-side options were
 * written into, and whatever a --depend named.  An edit to a
 * CMakeLists.txt is deliberately not one of them.  It doesn't have to
 * be: every build system cmake generates knows how to re-run cmake
 * itself when one of its inputs changes, so an edit is picked up by
 * the build rule re-entering the tree, at the cost of a regenerate
 * rather than of a rebuild from scratch.
 *
 * Starting over takes the default install prefix with it, and for the
 * same reason it takes the build directory: what a configuration
 * installed does not stop existing when the line that asked for it is
 * deleted.  Change '--define LLVM_ENABLE_PROJECTS=clang;lld' to
 * 'clang' and the lld in the prefix outlives the configuration that
 * built it -- still on the path of anything that looks one "bin" up,
 * and still enough to satisfy the "test -e" behind a
 * SUBPROJECT_TARGETS, so the build reports success while shipping a
 * tool it no longer builds.  A prefix a --prefix named is left where
 * it is: the reason anybody writes one is that several trees install
 * into it, and removing it here would take a peer's install away from
 * a peer whose stamp still says it is built and which therefore will
 * not install again.  A tree told --no-install has no prefix to take
 * at all -- the only directory it writes is the build directory, and
 * starting over already takes that.
 *
 * Which is also why the build-side options -- what to build, how many
 * jobs, whether to install -- are written into a file of their own
 * rather than into the one the configure hangs off.  They reach a
 * recipe, so something has to notice when they change; but noticing
 * them the way the configure-side options are noticed would spend a
 * whole rebuild of LLVM on somebody adding a '--target'.
 *
 * That second file is written by make, out of the recipe that reads
 * it, rather than by pconfigure.  The configure-side one can be
 * written by pconfigure because pconfigure writes it after the
 * Makefile: a run that dies part way through leaves neither, so the
 * file and the recipe it guards are always two halves of the same
 * run.  A build system writes its rules long before that, though, and
 * a file written from there is a file that can get ahead of the
 * Makefile.  That is not a theoretical ordering: pconfigure records
 * this run's build-side options, aborts over something else entirely
 * in the same Configfile, and leaves the old Makefile standing.  The
 * make that follows builds the tree the old way and stamps it newer
 * than a file that already says the new thing; the next run, once the
 * unrelated mistake is fixed, finds the file saying exactly what it
 * was about to write, leaves the mtime alone, and the tree stays
 * built the old way with nothing anywhere to say so.
 *
 * A file make writes out of the recipe cannot get ahead of the
 * recipe, which is the whole of why it is spelled this way.  The rule
 * hangs off a name that is never a file, so make asks it on every
 * build; the recipe writes the options only when what it has to say
 * differs from what is already there, so the mtime -- which is the
 * only thing anything downstream reads -- still moves exactly when an
 * option really moved.  Touching it on every configure instead would
 * have closed the same hole and charged a rebuild of LLVM for every
 * configure, which is the thing the two files exist to avoid.
 *
 * What it does cost is a rule that runs every time make runs, even in
 * a tree that is finished: a mkdir, a printf and a cmp per vendored
 * tree, saying nothing and leaving the file alone.  That is the price
 * of the answer rather than an accident of it -- a file that is
 * allowed to stop saying what the recipe says is the whole bug -- and
 * of the three ways to pay it, it is the small one.  pconfigure
 * writing the file costs nothing and is wrong, for the ordering
 * written out just above.  Touching the file on every configure costs
 * nearly nothing here and a rebuild of a vendored tree there, which
 * is minutes of somebody's day for having re-run pconfigure.  Three
 * shells is a few milliseconds, it is paid once per vendored tree
 * rather than once per source file -- there are a handful of these
 * rules in a project and tens of thousands of the other kind -- and
 * it is spent on a tree that was vendored precisely because building
 * it costs minutes.  Anything cheaper would have to make the rule
 * conditional on something, and the only thing to condition it on is
 * a file whose contents are what the rule exists to decide.
 *
 * What gets installed goes into --prefix, which defaults to a
 * directory inside this build system's own output directory rather
 * than to the project's own PREFIX.  That default is the careful one:
 * the install runs during "make", so a prefix of "/usr/local" would
 * mean a plain "make" writing into /usr/local, which is not a thing
 * any build should do without being asked twice.  A project that
 * wants several vendored trees to land in one directory -- which is
 * the usual reason to want this at all, since a toolchain is found by
 * looking one "bin" up -- says so with --prefix, and gets exactly one
 * path: the CMAKE_INSTALL_PREFIX the tree is configured with, the
 * directory the install lands in and the directory a
 * SUBPROJECT_TARGETS is named from are the same string, so there is
 * nothing for them to disagree about.
 *
 * Which of the cleaning targets may delete that directory has three
 * different answers, and every one of them is a way to lose an
 * installed toolchain quietly, so they are written down here:
 *
 *   - "make cache-clean" never, wherever the prefix points.  It works
 *     by reading the Makefile back and deleting everything in the
 *     object directory the Makefile can't say it builds, and what a
 *     vendored tree installs is exactly that: the only paths it would
 *     keep are the ones a SUBPROJECT_TARGETS named outright, so a
 *     toolchain comes back with those files and without its headers,
 *     its libraries and everything else -- and with a build stamp
 *     that still says the tree is built, so no make puts any of it
 *     back.  What keeps it out of that is that the cleaning code is
 *     told where every vendored tree installs and spares all of them:
 *     see build_system::install_dir().
 *
 *   - "make clean" takes the default prefix, beside the stamp it
 *     already took.  That costs nothing it wasn't already costing: a
 *     clean removes the stamp the install hangs off, so the next make
 *     re-enters the tree and installs again anyway.  What it buys is
 *     a way out of a stale prefix that doesn't involve knowing this
 *     file exists.  A prefix a --prefix named is left alone -- it was
 *     written down by a person, peer trees may be living in it, and a
 *     clean is not supposed to cost a reinstall of somebody else's
 *     tree.  So is the default prefix of a tree told --no-install,
 *     for the plainer reason that no such directory exists: a clean
 *     that named it would be saying this build installs somewhere,
 *     and it doesn't.
 *
 *   - "make distclean" takes it, and takes it without naming it.
 *     Both the default prefix and one a --prefix named are inside
 *     this project's object directory, which distclean removes whole,
 *     so there is nothing for distclean to know about either of them.
 *     That is the whole of what the rule about where a prefix may
 *     point buys: see build_system::install_dir() for the rule and
 *     build_system::checked_install_dir() for where it is enforced.
 *
 * What this deliberately does not do is translate CROSS_COMPILE into
 * anything.  CROSS_COMPILE is the name every toolchain program starts
 * with; cmake has no such notion and doesn't want one -- a cmake
 * cross build is a toolchain file that says which system is being
 * built for as well as which compiler.  A tree that has to be told
 * that is told with '--define CMAKE_TOOLCHAIN_FILE=...', which says
 * one thing once, and is not reconfigured over a CROSS_COMPILE it was
 * never shown.
 *
 * The options a CONFIGUREOPTS gives this are:
 *
 *   --generator NAME     The build system cmake writes, as cmake
 *                        spells it: '--generator Ninja'.  Defaults to
 *                        "Unix Makefiles", which is the one that gets
 *                        built by a recursive $(MAKE) -- and so the
 *                        only one that shares the jobserver of the
 *                        make that ran it instead of starting a
 *                        second, uncoordinated pool of its own.
 *                        Anything else is built by "cmake --build",
 *                        which is also what decides whether a MAKEOPS
 *                        or a --jobs means anything here.
 *
 *   --build-type NAME    -DCMAKE_BUILD_TYPE, which is asked for often
 *                        enough to be worth a name of its own:
 *                        '--build-type Release'.  Saying nothing
 *                        leaves the tree with whatever it defaults
 *                        to, which is cmake's business rather than
 *                        ours.
 *
 *   --define VAR=VALUE   A cache variable, reaching cmake as
 *                        '-DVAR=VALUE'.  The whole thing is handed
 *                        over as one argument however many spaces or
 *                        semicolons are in it, since a cmake list is
 *                        semicolon-separated and a semicolon in a
 *                        recipe would otherwise end the command.
 *                        "VAR:TYPE=VALUE" works too, being just
 *                        another spelling of the same argument.
 *
 *   --prefix DIR         Where the tree installs to, named relative
 *                        to the project that asked for it the same
 *                        way a SUBPROJECTS is.  Defaults to a
 *                        "prefix" directory beside the build.  It
 *                        reaches cmake absolutely, because cmake
 *                        bakes a prefix into the cache and into what
 *                        it builds.  Any directory inside that
 *                        project's object directory, like
 *                        "obj/toolchain": see
 *                        build_system::install_dir() for why that is
 *                        the rule and
 *                        build_system::checked_install_dir() for
 *                        where it is enforced.
 *
 *   --configure-arg ARG  One more argument for the cmake that
 *                        configures the tree, passed on exactly as
 *                        written and split by the shell the way any
 *                        other command line is: '--configure-arg
 *                        -Wno-dev'.  This is the way out for anything
 *                        cmake grew that the options above don't
 *                        cover.
 *
 *   --target NAME        Ask the tree for a target rather than for
 *                        whatever it builds when it's asked for
 *                        nothing.  May be given more than once, and
 *                        they're asked for one at a time in the order
 *                        they were given -- which is why one of them
 *                        reaches the build as one argument however
 *                        many spaces or semicolons are in it: two
 *                        targets are two of these rather than one
 *                        with a space in the middle.
 *
 *   --jobs N             How many jobs the build runs at once.  Only
 *                        for a generator that runs its own build, and
 *                        refused for one that runs make: a sub-make
 *                        takes its parallelism from the make that ran
 *                        it, and telling it a number of its own is
 *                        how a "make -j8" turns into sixty-four
 *                        compilers.
 *
 *   --install            Run the tree's install target after building
 *   --no-install         it, which is what happens unless it's turned
 *                        off.  What a SUBPROJECT_TARGETS names is
 *                        relative to whichever of the two directories
 *                        the tree last wrote into: the prefix when it
 *                        installs, and the build directory when it
 *                        doesn't.
 *
 *   --env NAME=VALUE     Put a variable in the environment the tree
 *                        is configured, built and installed in, where
 *                        the tree is allowed to disagree with it.  It
 *                        reaches the Makefile spelled exactly the way
 *                        it was written, so "$(abspath x)" and
 *                        "$(PATH)" mean what they say.
 *
 *   --depend PATH        Something the build has to wait for, and
 *   --depend-config PATH something the configuration has to wait for.
 *                        Either a file, or another vendored
 *                        subproject of the same project -- which
 *                        means waiting for that tree to be built
 *                        rather than for its directory to change.  A
 *                        --depend is waited for by both, since cmake
 *                        runs the compiler while it is deciding what
 *                        the tree can do; the price of that is that a
 *                        dependency which has been rebuilt
 *                        reconfigures this tree, and a reconfigure
 *                        here is a rebuild.
 *
 * Four of those hand a word of a Configfile to cmake or to the build
 * it generates: a --define, a --configure-arg, a MAKEOPS and an
 * --env.  A word that says where the tree installs, or which
 * directory is configured into which, is refused from all four -- see
 * build_system::refuse_second_answer(), which is where every one of
 * them asks and what already_answered() below hands the names to.
 * The one place either of those is said is the SUBPROJECTS and the
 * --prefix, which is where the rest of the build can read the answer.
 *
 * What that rule does not reach, and is not meant to, is a file the
 * vendored tree ships: a CMakeLists.txt with an absolute install()
 * DESTINATION, a toolchain file that sets a staging prefix, a
 * CMakePresets.json.  Those are the tree saying where it installs, in
 * the tree, and pconfigure reads none of them -- what is refused here
 * is a second answer written in a Configfile, where there is a line
 * to quote back and somebody to tell.
 *
 * A MAKEOPS puts a variable on the command line of the sub-make, for
 * the generators that have one.  There is no '--make-var' spelling of
 * it the way the kconfig build system has: a MAKEOPS already lands
 * wherever a CONFIGUREOPTS does, including under a BUILD_SYSTEMS, so
 * the second spelling would buy nothing and cost a second list to
 * keep in step with the first.
 */
class build_system_cmake: public build_system {
private:
    /* The build system cmake writes, as cmake spells it.  Kept as the
     * name rather than as a flag because two things are decided by
     * it: what goes after "-G", and whether the build is a recursive
     * make or a "cmake --build". */
    std::string _generator;

    /* CMAKE_BUILD_TYPE, or empty to say nothing about it.  This is a
     * cache variable like any other and could have been left to
     * --define; it has a name of its own because almost every tree
     * wants one and a build with an empty build type is the classic
     * way to end up with an unoptimized compiler. */
    std::string _build_type;

    /* The cache variables, in the order they were written, since a
     * later "-D" of the same name is the one cmake keeps. */
    std::vector<std::string> _defines;

    /* Everything else this run puts on the configuring cmake's
     * command line, in the order it was written. */
    std::vector<std::string> _configure_args;

    /* Where the tree installs to, exactly as the option wrote it:
     * resolving it needs the project this was bound to, and an
     * unbound build system -- which is what a CONFIGUREOPTS under a
     * BUILD_SYSTEMS lands on -- hasn't got one yet. */
    std::string _prefix;

    /* TRUE when the tree's install target is part of building it,
     * which it is unless somebody said otherwise. */
    bool _install;

    /* What to ask the vendored tree for.  Empty means whatever the
     * generated build system does when it's run with no target at
     * all, which is "all" for every generator cmake has. */
    std::vector<std::string> _make_targets;

    /* How many jobs the build runs at once, or empty for a build that
     * wasn't told.  A string rather than a number because it is going
     * into a command line either way, and because the digits are
     * checked where the option arrives rather than here. */
    std::string _jobs;

    /* The environment the vendored build system runs in.  An
     * environment variable and a cache variable are not the same
     * thing: a cache variable is written into the build directory and
     * is still true tomorrow, while something out of the environment
     * is only true for the run that saw it -- which is exactly the
     * difference you want for a PATH. */
    std::vector<std::string> _env;

    /* Edges that nothing can be inferred from: a vendored tree says
     * nothing about what it reads outside itself, and one vendored
     * tree says nothing at all about another. */
    std::vector<std::string> _depends;
    std::vector<std::string> _config_depends;

    /* Every CONFIGUREOPTS line this was handed, split by which of the
     * two rules reads it -- and an option that reaches both, like a
     * --env, is in both lists.
     *
     * build_system writes every option it was given into one
     * signature, which is the right answer for a build system where
     * noticing a changed option costs one more run of the thing that
     * reads it.  Here it isn't: a changed configure-side option means
     * the build directory is thrown away and made again, and a
     * changed build-side option means one more "cmake --build" in a
     * tree that is already built.  One file for the two of them would
     * charge the second price at the first rate. */
    std::vector<std::string> _configure_lines;
    std::vector<std::string> _build_lines;

public:
    build_system_cmake(const std::string& name);
    virtual ~build_system_cmake(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;
    std::string configure_signature(void) const;

    /* Where cmake was told to put its output, which is a directory of
     * ours that gets handed over rather than anything inside the
     * tree.  Everything of ours -- the stamp, the options this run
     * was given -- stays in output_dir() beside it, since this one is
     * cmake's and gets removed whole every time the tree is
     * configured. */
    std::string cmake_build_dir(void) const
        { return output_dir() + "/build"; }

    /* What cmake leaves behind to say it has configured that
     * directory.  It's a real file the tree writes rather than a
     * stamp of ours, which is what makes it worth hanging the build
     * off: a half-finished configure leaves no cache, so the next
     * make configures again rather than building something that was
     * never configured. */
    std::string cache_file(void) const
        { return cmake_build_dir() + "/CMakeCache.txt"; }

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

    /* TRUE when the prefix is the one this build system picked
     * because nobody said otherwise, rather than a directory a
     * --prefix named.  That is most of what decides which cleaning
     * targets may delete it: the default is this tree's own and comes
     * back on the next make, while a directory somebody wrote down is
     * one this tree shares with whatever else was pointed at it.  The
     * rest of it is whether the tree installs at all, since a prefix
     * nothing ever writes to is not a directory worth naming in an
     * "rm -fr". */
    bool private_prefix(void) const { return _prefix.size() == 0; }

    /* Which of those two directories a SUBPROJECT_TARGETS is named
     * from: the tree's last word about what it produced.  A tree that
     * installs has been asked to put its output somewhere for the
     * rest of the build to find, and that somewhere is the answer; a
     * tree that doesn't has only its build directory to offer. */
    std::string build_dir(void) const;

    std::string build_stamp(void) const
        { return output_dir() + "/build-stamp"; }

    /* What this run told the cmake that configures the tree, and what
     * it told the build that comes after it.  Two files because they
     * cost different amounts to act on -- see _configure_lines -- and
     * two writers because they can be written safely at two different
     * times: pconfigure writes the first, after the Makefile, and
     * make writes the second, out of the recipe that reads it. */
    std::string configureopts_file(void) const
        { return output_dir() + "/configure-opts"; }
    std::string buildopts_file(void) const
        { return output_dir() + "/build-opts"; }
    std::string build_signature(void) const;

    /* The name the rule that writes buildopts_file() hangs off, which
     * is never a file and so is never up to date.  It exists for one
     * reason: a file that says what the recipe says can only go on
     * saying it if something looks on every make. */
    std::string buildopts_force(void) const
        { return buildopts_file() + "-force"; }

protected:
    std::vector<makefile::target::ptr>
    vendored_targets(const std::vector<build_system::ptr>& peers,
                     const std::string& project_base) const;
    void take_configureopt(const std::string& opt);
    void take_makeopt(const std::string& opt);

    /* What cmake, and the build and install it generates, read as a
     * second answer to something this build system has already said:
     * where the tree installs, where each kind of file goes under
     * that, and which directory gets configured into which.
     *
     * Only the names are here.  What a word has to look like to be
     * one of them, what happens when it is, and what the diagnostic
     * says are build_system::refuse_second_answer()'s, which is what
     * every option below calls and the only thing that refuses any of
     * this -- the names are the tree's rather than pconfigure's
     * ("CMAKE_INSTALL_BINDIR" here, "bindir" one file over), and
     * nothing else about the question differs between them. */
    answers already_answered(void) const;

    /* TRUE only for a generator whose build is a recursive make,
     * which is what a MAKEOPS has to be true of to mean anything.
     * This catches a MAKEOPS written below the --generator that made
     * it meaningless; one written above it is caught when the rules
     * are written, since at the moment it arrives nothing yet knows
     * what the generator will be. */
    bool run_by_make(void) const;

    /* TRUE when the generator writes a Makefile for GNU make to read.
     * Spelled as "ends with 'Unix Makefiles'" so that the extra
     * generators -- "CodeBlocks - Unix Makefiles" and the rest, which
     * write an IDE project beside a perfectly ordinary Makefile --
     * come out on the right side of it.  The other Makefile
     * generators cmake has are for makes that are not this one, and a
     * "$(MAKE) -C" would hand them the wrong flags. */
    bool make_generator(void) const;

    /* Runs a command with the environment a CONFIGUREOPTS asked for.
     * These go in front of the whole command rather than after the
     * program's name, which is what makes them environment variables
     * rather than arguments -- and the two mean opposite things to
     * make. */
    std::string with_env(const std::string& command) const;

    /* What to run to build one target of the generated build system,
     * or the default one when the target is empty.  Both spellings of
     * this exist for one reason each: the recursive $(MAKE) is what
     * shares the jobserver, and "cmake --build" is what works for
     * everything that isn't a make. */
    std::string build_command(const std::string& target) const;

    /* What to print when nobody recognized an option, which is the
     * list of the ones that would have been recognized. */
    std::string configureopt_help(void) const;
};

#endif
