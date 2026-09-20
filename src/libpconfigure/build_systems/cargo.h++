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

#ifndef BUILD_SYSTEMS__CARGO_HXX
#define BUILD_SYSTEMS__CARGO_HXX

#include "../build_system.h++"

/* Cargo, which is how a Rust crate gets built.
 *
 * A SUBPROJECTS gets built this way when the directory it names has a
 * Cargo.toml in it.  That one file is the whole test, because that
 * one file is the whole of what a Rust tree looks like from outside:
 * nothing else is called that, a crate that has one always has it at
 * the top, and a crate that hasn't got one isn't a crate.
 *
 * Cargo is the odd one out among the vendored build systems here, and
 * it is worth saying how before saying anything else:
 *
 *   - It isn't make.  Nothing written out of here says "$(MAKE)", so
 *     there is no sub-make command line for a MAKEOPS to land on and
 *     run_by_make() says so -- a MAKEOPS under a cargo SUBPROJECTS is
 *     refused rather than accepted and quietly dropped.  Everything a
 *     MAKEOPS would have said is said with "--env" or "--arg"
 *     instead.
 *
 *   - There is no configure step.  A kbuild tree is configured by one
 *     rule and built by another; cargo reads its Cargo.toml, works
 *     out what has to happen and does it, all in the one command.  So
 *     there is one rule here rather than two, and the stamp it writes
 *     is what everything else hangs off.
 *
 *   - It does its own dependency tracking and its own incremental
 *     builds, and it is better at both than any guess made out here
 *     would be.  The file list below is not there to decide what gets
 *     recompiled -- it is there so that a "make" in a tree that is
 *     already built has a reason not to run cargo at all.
 *
 *   - It wants a network.  Nothing here can change that: a crate with
 *     dependencies it hasn't already downloaded needs either a
 *     populated CARGO_HOME or a registry to fetch from.  "--locked"
 *     and "--offline" are how a project that has made its own
 *     arrangements says so, and neither of them conjures a crate that
 *     isn't there.
 *
 * What cargo insists on is managing its own build directory, which is
 * a thing this wants anyway: the directory is "target" inside this
 * subproject's output directory, handed over with "--target-dir", and
 * that is what keeps a vendored crate from writing a "target" into
 * somebody else's checkout.  pconfigure's own bookkeeping -- the
 * stamp and the record of what this run was told -- sits beside it
 * rather than inside it, since what is inside is cargo's.
 *
 * What it is not told is where to find its own configuration: cargo
 * looks for ".cargo/config.toml" by walking up from the directory it
 * was started in, and a "--manifest-path" doesn't move that search.
 * So cargo is run from inside the crate, the way every other build
 * system here enters the tree it builds.  A vendored crate pins its
 * rustflags, its linker and the replaced registry an offline build
 * resolves against in that file, and a cargo run from anywhere else
 * would read the vendoring project's copy instead -- or nothing at
 * all.  It's watched for changes for the same reason, and it is the
 * one name beginning with a '.' that is.
 *
 * Running from in there is also the one thing that moves what a
 * relative path means, so every path this build system writes into
 * the recipe itself is absolute by the time make is done with the
 * line: the manifest, the target directory, the install root and the
 * cargo program.  The two that are still read from inside the crate
 * are the two written by hand and passed on verbatim -- the text of
 * an "--arg" and the value of an "--env" -- and both of them say so
 * below, because a path in one of those is the writer's to spell.
 *
 * They are quoted as well, which is a different question with the
 * same answer: a path in here is only ever absolute because make was
 * asked to make it so, and everything make hands back goes to a
 * shell.  Every one of them has a name somebody chose in the middle
 * of it -- the directory a SUBPROJECTS named, and under it the
 * object directory named after that -- and a directory is allowed an
 * apostrophe in its name.  Two things written out of here are
 * deliberately not quoted: the name in front of the '=' of an
 * "--env", which would stop being a shell assignment if it were,
 * and a "--jobs", which was proved to be nothing but digits where it
 * was written.
 *
 * Where a built program lands is "<target-dir>/<profile>/<name>", and
 * with a "--target" it is "<target-dir>/<triple>/<profile>/<name>".
 * Neither of those two middle components is a name anybody chose:
 * "--profile dev" makes a directory called "debug", which is a
 * mapping nobody should have to remember, and most people do not know
 * the triple component is there at all.  So build_dir() -- which is
 * what a SUBPROJECT_TARGETS is relative to -- is the whole of that
 * path, and a SUBPROJECT_TARGETS names the program: "wavediff",
 * rather than "release/wavediff".  The Configfile then says what the
 * tree produces instead of where cargo happens to put it, and a
 * project that moves from release to debug moves one line rather than
 * two.
 *
 * The price of that is an ordering rule, and it is a real one: the
 * options that decide the path -- "--release", "--profile" and
 * "--target" -- have to be written above anything that names an
 * output, because a SUBPROJECT_TARGETS and a TESTDEPS are both
 * resolved where they are written.  Writing them directly under the
 * SUBPROJECTS that pulled the tree in, above the SUBPROJECT_TARGETS
 * that names what it built, is what keeps that from ever coming up.
 *
 * The options a CONFIGUREOPTS gives this are:
 *
 *   --cargo PATH         The cargo to run.  Defaults to "cargo",
 *                        found on the PATH.  This is for a project
 *                        that pins a toolchain rather than taking
 *                        whatever rustup last pointed at.
 *
 *                        One word, and one word is the whole of it:
 *                        what goes into the recipe is a single
 *                        quoted word, because a directory is
 *                        allowed a space in its name, so a "--cargo
 *                        cargo +nightly" names a program nobody has
 *                        rather than running cargo with an
 *                        argument.  That spelling did reach the
 *                        shell as two words once, before the
 *                        quoting went in, and rustup does honour
 *                        the argument -- so it is refused where it
 *                        was written rather than left to fail at
 *                        "command not found" in the middle of a
 *                        build.  A toolchain is picked with an
 *                        "--env RUSTUP_TOOLCHAIN=nightly", or by
 *                        pointing this at a script that says the
 *                        rest.
 *
 *                        A word with no '/' in it is a program name
 *                        and is left alone, since the PATH is
 *                        searched the same way from every directory.
 *                        Anything else is a path, and a relative one
 *                        is read the way the project that vendored
 *                        the tree spells it -- the way an "--install"
 *                        is -- and written into the recipe
 *                        absolutely.  It has to be: the command runs
 *                        from inside the crate, so a "tools/cargo"
 *                        handed to the shell down there names a file
 *                        in somebody else's checkout, which on a good
 *                        day isn't there and on a bad day is.
 *
 *                        Being read the project's way, it may not
 *                        climb out of the project either: one that
 *                        did would name one program to a pconfigure
 *                        run at the top of the tree and another to a
 *                        run inside the project, so the line would
 *                        say which cargo to run without meaning it.
 *
 *                        Which is also why a value with a '$' in it
 *                        is refused rather than passed through.
 *                        pconfigure can't resolve what make hasn't
 *                        expanded yet, and wrapping an "$(abspath
 *                        ...)" somebody else wrote inside one of our
 *                        own builds a path out of two absolute
 *                        halves -- a path make hands to the shell
 *                        without complaining and the shell then
 *                        can't find.
 *
 *   --profile NAME       The cargo profile to build with.  Defaults
 *   --release            to cargo's own default, which is "dev".
 *                        "--release" is the same thing said the way
 *                        everybody writes it.  A profile is also a
 *                        directory name -- "dev" and "test" build
 *                        into "debug", "release" and "bench" into
 *                        "release", and anything else into a
 *                        directory of its own name -- which is why
 *                        a value with a '/' or a space in it is
 *                        refused: what it names is one directory,
 *                        so it is one word.
 *
 *                        Left off, the build says nothing and takes
 *                        that default, but an install is told it
 *                        outright: "cargo install" defaults to
 *                        "release" where "cargo build" defaults to
 *                        "dev", and two halves of one recipe that
 *                        disagree about the profile are two builds
 *                        landing in two directories, only one of
 *                        which anything here goes looking in.
 *
 *   --target TRIPLE      Build for another machine.  This is rustc's
 *                        spelling of a machine rather than a
 *                        toolchain prefix, so a project's
 *                        CROSS_COMPILE says nothing about it and
 *                        isn't passed on: "riscv64-linux-gnu-" and
 *                        "riscv64gc-unknown-linux-gnu" are two
 *                        different kinds of name and guessing one
 *                        from the other gets it wrong.
 *
 *                        A triple is a directory name too -- cargo
 *                        puts one named after it in front of the
 *                        profile -- so one with a '/' or a space in
 *                        it is refused for the reason a profile
 *                        is.
 *
 *   --package NAME       Which member of a workspace to build.  May
 *                        be given more than once.  A crate that isn't
 *                        a workspace has no use for this, and neither
 *                        has one that installs: "cargo install" has
 *                        no "--package" -- it installs whatever its
 *                        "--path" names -- so the two options
 *                        together are refused rather than turned into
 *                        a command line cargo rejects.  A workspace
 *                        member that is meant to be installed is
 *                        named by pointing the SUBPROJECTS at the
 *                        member's own directory.
 *
 *   --bin NAME           Which program to build, for a crate that
 *                        builds several and only one of them is
 *                        wanted.  May be given more than once.
 *
 *   --features LIST      Turn on cargo features, separated by spaces
 *   --all-features       or commas.  May be given more than once, and
 *   --no-default-features  they add up the way cargo adds them up.
 *
 *   --locked             Build against the committed Cargo.lock
 *   --offline            rather than whatever resolves today, and
 *                        build without asking the network.  A
 *                        vendored crate that is built as part of
 *                        somebody else's build wants both: a lock
 *                        file that silently moves is a build that
 *                        isn't reproducible, and a build that reaches
 *                        the network is a build that fails on a
 *                        machine that hasn't got one.
 *
 *   --jobs N             How many jobs cargo may run at once.  Cargo
 *                        does not take part in make's jobserver, so
 *                        a "make -j8" that reaches one of these has
 *                        two pools rather than one and this is the
 *                        only thing that bounds the second.
 *
 *   --arg TEXT           One more argument for "cargo build",
 *                        verbatim.  May be given more than once, and
 *                        each one arrives as a single argument
 *                        however many spaces are in it.  This is the
 *                        escape hatch for everything cargo can be
 *                        told that isn't worth a flag of its own;
 *                        the few arguments pconfigure has to decide
 *                        for itself are refused here rather than
 *                        silently fought over.  Those are the two
 *                        that say where cargo writes
 *                        ("--manifest-path" and "--target-dir"),
 *                        the three that decide which directory a
 *                        built program lands in ("--profile",
 *                        "--release" and "--target"), the one that
 *                        copies what was built somewhere else
 *                        ("--artifact-dir", and "--out-dir" under
 *                        its older name), and "--config" -- which
 *                        says any setting cargo has under cargo's
 *                        own name for it, three of those being the
 *                        ones above, and takes the name of a file
 *                        to read them out of as readily as it takes
 *                        a setting.  Each is refused in every
 *                        spelling cargo reads it by, which includes
 *                        the one-letter ones: a "-m" takes its path
 *                        stuck to it, and a cluster like "-qr" is a
 *                        "--release" with no name in it to find.  A
 *                        path written in one is read from inside
 *                        the crate, since that is where cargo is
 *                        run -- "$(abspath x)" is how to mean one
 *                        that isn't.
 *
 *   --env NAME=VALUE     Put a variable in the environment cargo runs
 *                        in, which is how RUSTFLAGS and CARGO_HOME
 *                        get said.  The value reaches the Makefile
 *                        exactly as it was written, so "$(abspath x)"
 *                        means what it says, and it arrives as one
 *                        word however many spaces are in it.  Which
 *                        is the other half of saying that a plain
 *                        relative path in one is read from inside the
 *                        crate, the same as one in an "--arg": these
 *                        two are passed on rather than resolved, so
 *                        where they point is whoever wrote them to
 *                        decide.
 *
 *                        The name is the other half, and it is the
 *                        half that gets no such latitude: it reaches
 *                        the recipe bare, because a quoted one would
 *                        stop being a shell assignment, so it has to
 *                        be what a shell reads as a variable name and
 *                        anything else is refused where it was
 *                        written.
 *
 *                        Four names are refused whatever they are
 *                        given, because each is the environment's
 *                        spelling of something already written on
 *                        cargo's command line out here:
 *                        CARGO_TARGET_DIR and
 *                        CARGO_BUILD_TARGET_DIR say where cargo
 *                        builds, CARGO_INSTALL_ROOT says where it
 *                        installs, and CARGO_BUILD_TARGET says
 *                        which machine it builds for -- which is
 *                        the one of the four cargo does not shadow,
 *                        since a "--target" is on the command line
 *                        only when a CONFIGUREOPTS asked for one.
 *                        A CARGO_HOME is not one of them: where the
 *                        downloaded registry lives answers nothing
 *                        this build system has said.
 *
 *   --install DIR        After building, run "cargo install --root"
 *                        into the named directory, which is where the
 *                        programs end up in "bin".  The directory is
 *                        named relative to the project that asked for
 *                        it rather than to the crate, since it's that
 *                        project's statement about where it wants its
 *                        tools -- so an absolute path is refused, and
 *                        so is one that climbs out of the project:
 *                        either would mean one directory to a "make"
 *                        at the top of the tree and another to a
 *                        "make" run in a project that pulled this one
 *                        in as a subproject.  Left off, nothing is
 *                        installed and the built program is named
 *                        with a SUBPROJECT_TARGETS instead -- which
 *                        is the cheaper answer when the only consumer
 *                        is this build.
 *
 *                        Where it may point is a directory inside
 *                        that project's object directory, like
 *                        "obj/toolchain", and nowhere else.  That
 *                        rule is the same one every vendored build
 *                        system here has, and it is stated once, in
 *                        build_system::install_dir().  What it keeps
 *                        out includes the one this build system
 *                        cares about most: cargo's habit of writing a
 *                        "target" beside the manifest is what
 *                        "--target-dir" exists to stop, and an
 *                        install root aimed back into the crate would
 *                        put the files there by hand -- leaving a
 *                        repository nobody here owns with programs in
 *                        it.
 *
 *                        What the cleaning targets do with it follows
 *                        from where it is: "make cache-clean" spares
 *                        it, since nothing in the Makefile builds
 *                        what cargo installs and cache-clean cannot
 *                        tell that from stale, while "make distclean"
 *                        removes the object directory and takes it
 *                        along without naming it.  "make clean" takes
 *                        the stamp and nothing else, which is enough:
 *                        the next build runs cargo again and installs
 *                        over what is there.
 *
 *   --depend PATH        Something the build has to wait for: either
 *                        a file, or another vendored subproject of
 *                        the same project -- which means waiting for
 *                        that tree to be built rather than for its
 *                        directory to change.
 */
class build_system_cargo: public build_system {
private:
    /* Which cargo to run.  A program name rather than a path by
     * default, so it's found the way everything else on a developer's
     * machine is found. */
    std::string _cargo;

    /* The cargo profile, or "" for the one cargo picks when it isn't
     * told -- which is "dev", and which is deliberately not written
     * in here as a default: an empty string means "we said nothing",
     * so the build's command line stays as short as what was asked
     * for.  The install's cannot: see install_profile(). */
    std::string _profile;

    /* The machine to build for, rustc's spelling, or "" for this
     * one.  This one matters to more than the command line: an
     * explicit triple puts a directory of its own in front of the
     * profile in cargo's output layout. */
    std::string _target;

    /* What to build, in the order it was asked for.  Empty means
     * whatever cargo builds when it isn't told, which for a crate
     * that produces one program is that program. */
    std::vector<std::string> _packages;
    std::vector<std::string> _bins;

    /* The feature flags, kept as they were written since cargo is the
     * thing that knows how to add them up. */
    std::vector<std::string> _features;
    bool _all_features;
    bool _no_default_features;

    /* Whether the build is pinned to the committed lock file, and
     * whether it's allowed to talk to a registry. */
    bool _locked;
    bool _offline;

    /* How many jobs cargo may run at once, or "" for cargo's own
     * answer, which is one per core and takes no notice of what make
     * is already running. */
    std::string _jobs;

    /* Everything else this build was told, in the order it was
     * written: extra arguments for the build, variables for the
     * environment it runs in, and the trees and files it waits for. */
    std::vector<std::string> _args;
    std::vector<std::string> _env;
    std::vector<std::string> _depends;

    /* Where "cargo install" puts what it built, or "" for a build
     * that installs nothing.  Named relative to the project that
     * asked for it, and kept raw until then: an option is handled
     * while the build system is still unbound, when there is no
     * project to be relative to yet. */
    std::string _install_root;

public:
    build_system_cargo(const std::string& name);
    virtual ~build_system_cargo(void) {}

public:
    /* Virtual methods from build_system. */
    build_system* clone(void) const;
    bool can_build(const std::string& base) const;

protected:
    std::vector<makefile::target::ptr>
    vendored_targets(const std::vector<build_system::ptr>& peers,
                     const std::string& project_base) const;
    void take_configureopt(const std::string& opt);

    /* Nothing written out of here is a make, so a MAKEOPS has no
     * command line to go on.  Saying so is what turns a MAKEOPS
     * written under one of these from a line that is quietly ignored
     * into a line that says what to write instead. */
    bool run_by_make(void) const { return false; }

protected:
    /* Takes one CONFIGUREOPTS, and answers whether it was one of
     * these.  Split out from take_configureopt() the way kconfig
     * splits it, so that a build system built on top of this one can
     * add a flag without the spelling of every other flag moving. */
    virtual bool handle_configureopt(const std::string& opt);

    /* What to print when nobody recognized an option, which is the
     * list of the ones that would have been recognized. */
    virtual std::string configureopt_help(void) const;

private:
    /* The first word of both commands this writes, which is not
     * always the word the option said.  The recipe runs from inside
     * the crate, so a relative path has to be made absolute out here:
     * left as it was written it would name a file under the vendored
     * tree, which is either nothing at all -- a build that dies on
     * "not found" -- or, in a tree that happens to have a directory
     * of that name, somebody else's program run without anybody
     * asking for it.  A bare program name is handed over untouched,
     * since a PATH search doesn't care where it was started from.
     *
     * This needs the project the build system was bound to, the same
     * way install_root() does, which is why it isn't done where the
     * option was read. */
    std::string cargo_program(void) const;

    /* Runs a command with the environment a CONFIGUREOPTS asked for.
     * These go in front of the whole command rather than after the
     * program's name, which is what makes them environment variables
     * rather than arguments.
     *
     * The value is quoted and the name is not, which is the only way
     * round that works.  The variables a Rust build is given are
     * RUSTFLAGS and friends, whose values have spaces in them as a
     * matter of course, and an unquoted "RUSTFLAGS=-C
     * target-cpu=native" is a RUSTFLAGS worth "-C" followed by a
     * program called "target-cpu=native" -- while the same thing
     * quoted whole has stopped being an assignment at all and is the
     * name of a program nobody has.  Quoting only the value leaves a
     * shell assignment in front of a command, which is what this is
     * for, and make still expands what's inside the quotes because
     * make has no idea they're there.
     *
     * Which leaves the name as the one piece of a CONFIGUREOPTS that
     * reaches a recipe unquoted, and that is why handle_configureopt()
     * insists it is a name a shell will read as one. */
    std::string with_env(const std::string& command) const;

    /* The arguments that say what to build, which "cargo build" and
     * "cargo install" both understand and both have to be told the
     * same.  A crate built with one set of features and installed
     * with another is two builds, and the second one is the one
     * nobody asked for.
     *
     * The profile is an argument rather than read off _profile
     * because that is the one thing the two commands can't be handed
     * identically: see install_profile(). */
    std::string selection_flags(const std::string& profile) const;

    /* And the arguments only "cargo build" understands, which is
     * exactly one: "cargo install" has no "--package".  This is a
     * function of its own rather than a line in selection_flags()
     * because that is where the shared/not-shared distinction is
     * easy to get wrong -- handing an install a flag it doesn't take
     * is a build that fails after the build half has succeeded, a
     * long way from anything anybody wrote. */
    std::string build_only_flags(void) const;

    /* Which profile "cargo install" gets told, which is never
     * nothing.  "cargo build" with no "--profile" builds "dev" and
     * "cargo install" with no "--profile" builds "release" -- that
     * asymmetry is why "cargo install" has a "--debug" flag at all --
     * so a recipe that says nothing to either of them builds the
     * crate twice and installs the half that build_dir() isn't
     * pointing at.  Saying it outright is what keeps the two halves
     * talking about one directory. */
    std::string install_profile(void) const;

    /* Where "cargo install --root" is told to put things, resolved
     * against the project that asked for it.  This needs the project
     * the build system was bound to, which is why it isn't done where
     * the option was read, and it aborts on the directories
     * build_system::checked_install_dir() refuses -- which is
     * everything that is not inside that project's object
     * directory. */
    std::string install_root(void) const;

    /* The directory cargo writes a built program into, relative to
     * its target directory: the profile, with the triple in front of
     * it when there is one.  This is cargo's own layout rather than a
     * choice, so the mapping from a profile to a directory is cargo's
     * too -- "dev" and "test" share "debug", "release" and "bench"
     * share "release", and a profile of your own gets a directory of
     * its own name. */
    std::string artifact_dir(void) const;

    /* Every file in the crate that could be worth re-running cargo
     * over.  This is a guess, and a generous one: cargo decides what
     * actually gets recompiled, so all this has to do is be wrong in
     * the direction of running cargo when it needn't have. */
    std::vector<std::string> source_deps(void) const;

public:
    /* Where "cargo install" left things, or "" for a crate that
     * installs nothing, which is the shape the cleaning targets want:
     * see build_system::install_dir(). */
    std::string install_dir(void) const;

    /* Where cargo is told to put everything it builds.  This is
     * pconfigure's answer to cargo's "target" directory, which is the
     * one thing keeping a vendored crate from writing into somebody
     * else's checkout: without it cargo makes a "target" beside the
     * Cargo.toml, inside the tree we promised not to write in. */
    std::string cargo_target_dir(void) const
        { return output_dir() + "/target"; }

    /* Which is not where a built program lands: that's a couple of
     * directories further down, and a SUBPROJECT_TARGETS is relative
     * to where the thing it names actually is. */
    std::string build_dir(void) const
        { return cargo_target_dir() + "/" + artifact_dir(); }

    /* The stamp that says cargo has been run since anything it reads
     * changed.  Beside the target directory rather than inside it,
     * since that directory is cargo's: it keeps a fingerprint
     * database in there and has every right to throw away anything it
     * doesn't recognize. */
    std::string build_stamp(void) const
        { return output_dir() + "/build-stamp"; }

    /* What this run was told, which is the only prerequisite of the
     * build rule that isn't a file somebody already had -- and so the
     * only thing that can tell make that the options changed.  The
     * base class's signature is the whole of it here: everything that
     * reaches cargo arrived as a CONFIGUREOPTS, there are no MAKEOPS
     * because there is no make, and this build system deliberately
     * reads nothing else off the context. */
    std::string configureopts_file(void) const
        { return output_dir() + "/configure-opts"; }
};

#endif
