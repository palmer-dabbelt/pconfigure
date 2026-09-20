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

#ifndef BUILD_SYSTEM_HXX
#define BUILD_SYSTEM_HXX

#include "context.h++"
#include <libmakefile/target.h++>
#include <memory>
#include <string>
#include <vector>

/* How a SUBPROJECTS gets built.
 *
 * A build system stands in the same relation to SUBPROJECTS that a
 * language stands in to SOURCES: BUILD_SYSTEMS says which ones are
 * available, and the directory a SUBPROJECTS names decides which of
 * those actually builds it, by what's in it.  A directory with a
 * Configfile is a pconfigure project; one with a Kconfig and a
 * Makefile is a kbuild tree; nobody has to say so.
 *
 * pconfigure itself is one of these, and it's the one that's always
 * available -- there's an implicit "BUILD_SYSTEMS += pconfigure" at
 * the bottom of every project.  It's also the only one that isn't
 * vendored: a pconfigure subproject is read and folded into this
 * run, while everything else is a third-party tree that gets built by
 * running its own build system.
 *
 * Two copies of a build system exist.  The one BUILD_SYSTEMS made is
 * unbound: it says the build system is available and carries the
 * CONFIGUREOPTS that every subproject using it should get.  A
 * SUBPROJECTS binds a copy of that to one directory, which is what
 * ends up producing targets. */
class build_system {
public:
    typedef std::shared_ptr<build_system> ptr;

private:
    /* What a BUILD_SYSTEMS command calls this. */
    const std::string _name;

    /* Where the tree this was bound to is, relative to the directory
     * pconfigure ran in, ending with a '/'.  Empty while unbound. */
    std::string _base;

    /* The context the SUBPROJECTS showed up in, which is where the
     * object directory that this builds into comes from.  NULL while
     * unbound. */
    context::ptr _context;

    /* Every CONFIGUREOPTS this build system was handed, in the order
     * they were written.  What an option means is the build system's
     * business, but that one was written at all is this class's: it's
     * what a later run compares itself against to find out that the
     * tree has to be configured again. */
    std::vector<std::string> _configureopts;

    /* Every MAKEOPS this build system was handed, in the order they
     * were written.  These go on the command line of the make that
     * builds the tree, where a variable beats whatever the tree's own
     * Makefile has to say about it. */
    std::vector<std::string> _makeopts;

    /* Which of those came in as a CONFIGUREOPTS rather than as a
     * MAKEOPS, one entry per variable.  A build system is allowed to
     * spell this as an option of its own -- kbuild's "--make-var" is
     * the same thing said the other way -- and an option is already
     * written into the signature as the option it was, so writing it
     * again as a variable would say one thing twice. */
    std::vector<bool> _makeopt_from_option;

    /* TRUE while a CONFIGUREOPTS is being handed over, which is how
     * the above gets filled in without every build system having to
     * remember to say so. */
    bool _taking_configureopt;

    /* The files a SUBPROJECT_TARGETS said this tree produces, named
     * relative to the directory it builds into. */
    std::vector<std::string> _subproject_targets;

public:
    build_system(const std::string& name);
    virtual ~build_system(void) {}

public:
    /* Accessor methods. */
    const std::string& name(void) const { return _name; }
    const std::string& base(void) const { return _base; }
    const context::ptr& ctx(void) const { return _context; }

    /* The tree this builds, spelled the way "make -C" wants it. */
    std::string source_dir(void) const;

    /* Where this build system's output goes.  A vendored tree is
     * somebody else's, so nothing gets written inside it: the output
     * lands in the object directory of the project that pulled it in,
     * under a name that no two build systems and no two subprojects
     * can collide on. */
    std::string output_dir(void) const;

    /* Where inside that the tree actually puts what it builds, which
     * is what a SUBPROJECT_TARGETS names things relative to.  These
     * are the same directory unless a build system keeps something of
     * ours alongside the tree's output, which is what kbuild's O=
     * makes it do. */
    virtual std::string build_dir(void) const { return output_dir(); }

    /* Where this build system installs what it built, or "" for one
     * that installs nothing.
     *
     * AN INSTALL PREFIX IS A DIRECTORY INSIDE THE OBJECT DIRECTORY OF
     * THE PROJECT THAT VENDORED THE TREE, NAMED RELATIVE TO THAT
     * PROJECT.  pconfigure owns every byte under an object directory,
     * so a directory in there holds build output and nothing else --
     * nothing checked in, no other project, no vendored tree -- and a
     * path that stays inside the project names the same directory
     * whether pconfigure was run in that project or in one above it.
     * That is the whole of the model; build_system::checked_install_dir()
     * is where it is enforced, and this is the only comment that gets
     * to state it.
     *
     * What follows from it is that only one of the two cleaning
     * targets has anything to do with this function:
     *
     *   - "make distclean" removes every project's object directory,
     *     so it already removes every install prefix, by name and
     *     without being told.  Nothing in the distclean code says the
     *     word "prefix", and nothing in it should: an install prefix
     *     is the one build path a Configfile author writes by hand,
     *     and a path somebody wrote by hand is not a thing to paste
     *     into an "rm -rf" on the strength of a check.
     *
     *   - "make cache-clean" walks an object directory and reclaims
     *     whatever the Makefile has stopped naming as a target, and
     *     what an install left behind is exactly that.  A vendored
     *     tree's rules all hang off one stamp: the recipe behind that
     *     stamp configures, builds and installs, and the headers, the
     *     libraries and the programs that land in the prefix have no
     *     rules at all -- only the files a SUBPROJECT_TARGETS named
     *     outright get one.  So cache-clean has to be handed this
     *     directory and told to spare it, or it deletes all of that,
     *     leaves the stamp saying the tree is installed, and no later
     *     make puts any of it back.  The first thing to fail is a
     *     compile against a header that was there yesterday.
     *
     * So this exists for project::cache_clean_target() and for
     * nothing else.  It is on build_system rather than inside each
     * build system because a prefix shared between several trees --
     * which is the usual reason to write the option at all, since a
     * toolchain is found by looking one "bin" up -- is inside the
     * object directory but inside no single tree's output directory,
     * and the code that spares directories is walking the object
     * directory rather than the trees.
     *
     * Trees sharing a prefix install into it concurrently under a
     * "make -j", and nothing here stops them.  That is deliberate:
     * installing several trees into one directory is the thing the
     * option is for, the files each of them writes are its own, and
     * serializing the stamps would turn the one arrangement somebody
     * reached for into the one arrangement that builds no faster on a
     * machine with cores to spare.  What two trees may not do is
     * claim the same file, which is a thing that can be seen from
     * here rather than guessed at, and targets() refuses it. */
    virtual std::string install_dir(void) const { return ""; }

public:
    /* Returns a deep copy.  Like language::clone this hands back a
     * regular pointer, since C++11 has no covariant return types for
     * shared_ptr. */
    virtual build_system* clone(void) const = 0;
    ptr dup(void) const { return ptr(clone()); }

    /* TRUE when the tree at the given path -- a directory ending with
     * a '/' -- is one this build system knows how to build.  This is
     * what picks a build system for a SUBPROJECTS, so it has to
     * answer by looking at what's in the directory. */
    virtual bool can_build(const std::string& base) const = 0;

    /* FALSE only for pconfigure itself, which doesn't get run as a
     * build system: its subprojects are read into this run instead. */
    virtual bool vendored(void) const { return true; }

    /* Handles one CONFIGUREOPTS line, and remembers that it was
     * given.  What an option means is up to the build system it was
     * handed to, so the line is passed on exactly as it was
     * written. */
    void add_configureopt(const std::string& opt);

    /* Handles one MAKEOPS line, which is a variable to put on the
     * command line of the make that builds this tree.
     *
     * What was written is what make is told, character for character.
     * Taking it apart here would mean putting it back together later,
     * and every way of doing that gets a value with a space or a '$'
     * in it wrong -- while a value that reaches the Makefile
     * untouched lets whoever wrote it say "$(abspath x)" and mean
     * it. */
    void add_makeopt(const std::string& opt);

    /* Handles one SUBPROJECT_TARGETS line: a file this tree produces,
     * named relative to the directory it builds into.
     *
     * This exists because a vendored tree's rules all hang off one
     * stamp that says the tree has been built, and a stamp is not
     * something anything else can name.  A project that wants to wait
     * for the kernel image rather than for the kernel says which file
     * that is, and gets a target it can put in a TESTDEPS or on a
     * link line like any other path. */
    void add_subproject_target(const std::string& path);

    /* TRUE when a SUBPROJECT_TARGETS said this tree produces the
     * given path, spelled the way the Makefile spells it.  This is
     * how one vendored tree gets to wait for a file another one
     * builds: the file has a rule behind it, so it doesn't have to
     * already exist to be named. */
    bool produces(const std::string& path) const;

    /* Everything this run told the vendored tree that a rule's
     * recipe is built out of, written down so that two runs can be
     * compared.
     *
     * This exists because of a hole nothing else can fill: every
     * prerequisite a vendored tree's rules have is a file that
     * belonged to the tree or to the project before pconfigure ran,
     * and a recipe changing is not a reason for make to run a rule.
     * So a build reconfigured with different CONFIGUREOPTS would sit
     * there configured the old way, with a Makefile that says
     * otherwise.  Writing the options into a file gives make
     * something that changes when the answer changes.
     *
     * The options say most of it; a build system that's told
     * anything else has to say so. */
    virtual std::string configure_signature(void) const;

    /* Where that gets written, or "" for a build system that has
     * nothing to write -- which is the same answer, and for the same
     * reason, that build_stamp() gives. */
    virtual std::string configureopts_file(void) const { return ""; }

    /* The targets that drive this build system, which go into the
     * Makefile of the project that pulled the tree in -- a vendored
     * tree's own Makefile belongs to the tree.
     *
     * "peers" is every vendored tree the same project pulled in,
     * which is how a subproject that has to be built after another
     * one finds out what to wait for.  Nothing else about a peer is
     * any of this one's business.
     *
     * The rules a SUBPROJECT_TARGETS asks for are added here rather
     * than by each build system, since they're the same rules
     * whatever built the tree and forgetting them would be silent. */
    std::vector<makefile::target::ptr>
    targets(const std::vector<ptr>& peers,
            const std::string& project_base) const;

    /* The file that says this build system has been run since
     * anything it reads changed, or "" for one that hasn't got a
     * single such file.  This is what a subproject that has to wait
     * for another one hangs itself off. */
    virtual std::string build_stamp(void) const { return ""; }

protected:
    /* The targets that actually drive this build system.  This is the
     * half of targets() that knows how a tree gets built, and it's
     * the only half a build system has to write. */
    virtual std::vector<makefile::target::ptr>
    vendored_targets(const std::vector<ptr>& peers,
                     const std::string& project_base) const = 0;

    /* Takes one CONFIGUREOPTS line.  This is the half of
     * add_configureopt() that knows what an option means, and it's
     * the only half a build system has to write. */
    virtual void take_configureopt(const std::string& opt) = 0;

    /* The same for a MAKEOPS, and for the same reason: what a
     * variable on the sub-make's command line means to the tree is
     * the tree's business, and add_makeopt() only knows what every
     * variable has in common.  A build system with nothing to say
     * about any of them says nothing, which is why this has a body.
     *
     * A build system that spells a MAKEOPS as an option of its own --
     * kbuild's "--make-var", autotools' the same -- reaches this
     * through add_makeopt() like any other, so a check written here
     * covers both spellings.  What it cannot do is name the option
     * the Configfile actually wrote, since nothing that gets this far
     * remembers; an option that wants its own name in the diagnostic
     * asks where it is read. */
    virtual void take_makeopt(const std::string&) {}

    /* TRUE for a build system that is run by running make, which is
     * what a MAKEOPS has to be true of to mean anything. */
    virtual bool run_by_make(void) const { return true; }

    /* The variables a MAKEOPS put on the command line of the make
     * that builds this tree, with a leading space and in the order
     * they were written. */
    std::string makeopt_flags(void) const;

    /* The same list, for a build system that has to look at what's in
     * it rather than just hand it over. */
    const std::vector<std::string>& makeopts(void) const
        { return _makeopts; }

    /* A path a Configfile wrote, resolved against the project that
     * wrote it and refused when it names somewhere outside that
     * project.  "flag" is the option as that build system's
     * diagnostics spell it, "written" is the path exactly as the
     * Configfile wrote it so that an error can quote the line back,
     * and "example" is a spelling of it that would have worked.
     *
     * The refusing is the whole point, and the reason is that a
     * Configfile line has to mean one thing.  pconfigure works in
     * paths relative to the directory it ran in, and which directory
     * that is depends on whether a project was configured on its own
     * or pulled in by a parent.  A path that stays inside the project
     * means the same file either way, because the Makefile names it
     * through the project's own prefix variable and that variable is
     * what changes between the two runs.  A path that climbs out has
     * nothing for that variable to attach to, so it quietly names two
     * different directories -- and which of them it names depends on
     * who ran pconfigure, which is not something the line says.
     *
     * The resolving happens here rather than where the option was
     * read because an option is read while the build system is still
     * unbound: a CONFIGUREOPTS written under a BUILD_SYSTEMS belongs
     * to every subproject built that way, and there is no one project
     * for it to be relative to yet. */
    std::string checked_project_path(const std::string& flag,
                                     const std::string& written,
                                     const std::string& example) const;

    /* The same, for whatever a build system spells its install prefix
     * -- a --prefix here, a --install there -- with the one further
     * demand that it name a directory inside the object directory of
     * the project that vendored the tree.  See install_dir() for what
     * that rule is and what it buys; this is where it is enforced.
     *
     * One copy of this rather than one per build system, because
     * there is one answer and the three that had their own had three
     * spellings of it and three different sets of rules.
     *
     * The object directory itself is not one of the directories
     * inside it.  "make cache-clean" spares an install prefix,
     * because it cannot tell what an install left from what a
     * configuration abandoned, so a prefix that is the whole object
     * directory is a cache-clean that reclaims nothing at all -- and
     * says nothing about it, since it still runs and still finishes.
     *
     * Neither are the directories under it that pconfigure writes
     * into itself, which is the same sentence one level down: the
     * objects this project compiles, the programs it links and the
     * files a GENERATE wrote each have a place inside the object
     * directory, and "obj/src" spared whole is the same cache-clean
     * that reclaims nothing.  Owning every byte of the object
     * directory is what lets a prefix be in there; it is not the
     * same as having none of it spoken for. */
    std::string checked_install_dir(const std::string& flag,
                                    const std::string& written) const;

    /* One thing a vendored tree reads off its own command line that
     * this build system has already decided: the name the tree calls
     * it, and the sentence a diagnostic uses to say what it settles.
     *
     * The names are the tree's rather than pconfigure's -- "bindir"
     * is what a GNU build calls it, "CMAKE_INSTALL_BINDIR" what a
     * cmake build calls it, "INSTALL_MOD_PATH" what a kbuild tree
     * does -- so the list lives with the build system that knows
     * them, and only the matching and the refusing are here. */
    struct answer {
        std::string name;
        std::string decides;
    };

    /* Everything a vendored tree would read as a second answer to
     * something this build system has already said on that tree's own
     * command line, and how a word on that command line spells one.
     *
     * A build system fills this in and refuse_second_answer() asks
     * it.  There is one of these rather than one check per build
     * system because the question is the same one every time and the
     * three that had their own had three spellings of it: a variable
     * refused in one place and waved through in another is worse than
     * one that was never refused at all, since it reads as a closed
     * door. */
    struct answers {
        /* Where the whole install goes.  Refused by name, whatever
         * the value: which of two answers the tree obeys is decided
         * by the order this code composes a command line in, which is
         * not a thing anybody reading the Configfile can see. */
        std::vector<answer> destinations;

        /* Where one kind of file goes inside that -- a "bindir", a
         * "CMAKE_INSTALL_LIBDIR".  These are told apart from the
         * destinations because a value that stays under the prefix
         * cannot move anything out of the object directory, so
         * whether one of these is refused depends on what it was
         * given rather than only on its name.  See
         * relative_subdirectories. */
        std::vector<answer> subdirectories;

        /* The directories this build system named on that same
         * command line: which tree is being configured and where it
         * builds.  A second answer to either of those is the install
         * escape one option across -- cmake keeps the last "-B" it is
         * given, so a '--configure-arg -B /tmp/elsewhere' leaves a
         * whole build tree somewhere nothing in the project ever
         * removes, and a "-S" one word over builds a tree the
         * SUBPROJECTS never named.
         *
         * These are matched both ways round, because the two trees
         * spell them differently and the question is the same one: as
         * a decorated name like everything above, which is what
         * catches autoconf's "--srcdir=", "-srcdir=", "--src=" and
         * bare "srcdir=" in one go; and as a whole word, which is
         * what catches a cmake "-B" that takes its directory glued
         * on or in the word after and has no name inside it to look
         * for.  A one- or two-character spelling takes whatever is
         * stuck to it, a longer one takes a value after an '=' or in
         * the next word. */
        std::vector<answer> directories;

        /* What a name arrives wearing when the word is an option
         * rather than a variable: "--" and "-" for a generated
         * configure, "-D" for a cmake cache variable.  The empty
         * string is always one of them, since every one of these
         * trees also reads a bare "NAME=VALUE", and the longest one
         * that matches is the one taken -- "-D" rather than "-" for a
         * "-DCMAKE_INSTALL_PREFIX". */
        std::vector<std::string> decorations;

        /* TRUE when the tree reads a shortened "--" spelling as the
         * whole name, which a generated configure does: autoconf
         * writes out every truncation of every option it takes, so
         * "--p=", "--pre=" and "--prefi=" are all "--prefix=", and
         * "--bi=" is "--bindir=".  A list that matched whole names
         * refused "--prefix=/usr/local" and accepted "--pre=", which
         * is the same line with three characters taken off it.
         *
         * Only the "--" spelling, because that is the only one
         * autoconf abbreviates: its single-dash forms are the full
         * name and nothing shorter.  What this costs is an option
         * whose name is a strict prefix of one of the names above --
         * a hand-written configure's "--lib=", say -- which a
         * generated configure would have refused as ambiguous
         * anyway. */
        bool abbreviated;

        /* TRUE when a '-' inside a name is the '_' of the variable it
         * sets, which is how autoconf spells "--exec-prefix" and
         * "exec_prefix" as one thing. */
        bool dashed;

        /* TRUE when a relative value of one of the subdirectories is
         * read under the install prefix, which is cmake's answer:
         * install() joins a relative DESTINATION to
         * CMAKE_INSTALL_PREFIX, so "-DCMAKE_INSTALL_LIBDIR=lib"
         * cannot name anything outside the prefix and there is no
         * reason to refuse it.  An absolute one, or one that climbs
         * with a "..", or one with a '$' that make expands into
         * either, is refused whatever this says.
         *
         * FALSE for a tree that reads a relative one somewhere else,
         * which is autoconf's answer: the GNU directory variables are
         * absolute paths by construction, and the tree's own make
         * reads a relative one from the directory it builds in rather
         * than from the prefix -- so "under the prefix" is a thing
         * that spelling cannot say, and accepting it would be
         * accepting a line that does not mean what it looks like. */
        bool relative_subdirectories;

        /* How this build system spells the one option that does say
         * where the tree installs, as the advice should tell somebody
         * to write it: "--prefix DIR".  Empty for a build system that
         * hasn't got one, whose advice then says so rather than
         * naming an option nobody can write. */
        std::string prefix_option;

        answers(void)
        : destinations(), subdirectories(), directories(),
          decorations{""}, abbreviated(false), dashed(false),
          relative_subdirectories(false), prefix_option()
        {}
    };

    /* What this build system has already said on the vendored tree's
     * own command line, or nothing for one that says none of it.
     *
     * This is the half of refuse_second_answer() that knows what the
     * tree calls things, and it's the only half a build system has to
     * write. */
    virtual answers already_answered(void) const { return answers(); }

    /* Refuses one word bound for a vendored tree's own command line
     * when it is a second answer to something this build system has
     * already answered there -- where the tree installs, where it
     * builds, which tree is being built.  "flag" is the option as
     * this build system's diagnostics spell it ("--define",
     * "--configure-flag", "--env", "MAKEOPS"), and "written" is what
     * came after it, so that an error can quote the line back.
     *
     * THIS IS THE ONE ENTRY POINT.  A build system that runs a tree
     * which can be told where to install says so by overriding
     * already_answered(), and then calls this from every place a word
     * of a Configfile reaches that tree: the flags, the variables,
     * the make variables and the environment.
     *
     * Four of the five build systems here are through it: autotools,
     * cmake, kconfig and buildroot, which inherits kconfig's and adds
     * its own names.  Each of those reads a decorated NAME=VALUE --
     * "--prefix=", "-DCMAKE_INSTALL_PREFIX=", a bare
     * "INSTALL_MOD_PATH=" on a make command line -- which is the
     * grammar the answers above describe and the matcher below knows.
     *
     * cargo is the exception, and it is a named one rather than an
     * omission.  Nothing cargo reads is a decorated NAME=VALUE: what
     * says where it installs is a "--root" taking the next word, what
     * says where it builds is a "--target-dir", and a "-rm" is two
     * one-letter flags of which the second takes what is stuck to it.
     * A list of names and decorations cannot say any of that, and an
     * "answers" that grew a way to would be a second grammar living in
     * the same struct as the first.  So cargo asks the same question
     * in its own words, in reserved_flag() and reserved_variable() --
     * and it can ask it of the first word of an option rather than of
     * every word, because one "--arg" is quoted whole into one
     * argument to cargo, where a "--configure-arg" is pasted raw and
     * can be several.  What the two have in common is the rule, not
     * the code: every channel that reaches the tree is asked, and a
     * name refused in one of them is refused in all of them.
     *
     * Every word of "written" is asked rather than the first, because
     * an option that reaches the tree raw -- a --configure-arg, a
     * --configure-flag -- is written the way it will appear on a
     * command line, so one of them can be several arguments and the
     * one that matters may be any of them.
     *
     * What it will not do is guess.  A name that isn't on the list
     * this build system handed over is a name this build system has
     * no opinion about, which is the whole reason the lists are
     * written out rather than matched by shape: "--sbindir" says
     * where a program lands and "--with-sysroot" doesn't, and from a
     * distance they are the same word. */
    void refuse_second_answer(const std::string& flag,
                              const std::string& written) const;

    /* One NAME=VALUE bound for the environment of a command this
     * build system writes, refused when it isn't one.  "flag" is the
     * option as that build system's diagnostics spell it, "written"
     * is what came after it so that an error can quote the line back,
     * and "example" is a NAME=VALUE that would have worked.
     *
     * The name in front of the '=' is the one piece of a
     * CONFIGUREOPTS that reaches a recipe unquoted, and it has to be:
     * quoted, it stops being a shell assignment and becomes the name
     * of a program nobody has.  So the shell's own rule about what a
     * name is has to be enforced out here, where the line that got it
     * wrong can still be quoted back.  Left to the recipe, an
     * "--env RUST FLAGS=-O2" writes "RUST FLAGS='-O2' cargo build",
     * which a shell reads as an assignment to FLAGS in front of a
     * program called "RUST" -- so the build dies at "RUST: command
     * not found" a long way from the Configfile, or, on a machine
     * where something of that name happens to be on the PATH, doesn't
     * die at all.
     *
     * One copy of this rather than one per build system.  There were
     * four, three of them asking only whether there was an '=' in the
     * line at all, so the same Configfile line was refused by one
     * build system and waved through by the other three -- and what
     * the three of them produced was an Error 127 in the middle of a
     * build, from a line that had been read without a murmur. */
    void checked_env(const std::string& flag,
                     const std::string& written,
                     const std::string& example) const;

    /* The value a flag was given, or "" when this option isn't that
     * flag.  Both "--flag value" and "--flag=value" turn up in the
     * wild and neither is any harder to read than the other, so both
     * are read -- which is the convention, and the reason this is in
     * one place is that a convention spelled four times is four
     * conventions that have not disagreed yet.
     *
     * It was spelled four times.  Every one of those four carried a
     * comment saying it was the second copy and that a third would
     * mean hoisting it, and they were right about the rule and wrong
     * about the count: three of them were written in the same round
     * as each other, so each was the third or the fourth while saying
     * it was the second.  That is what a comment about how many
     * copies of something there are is worth, and it is why the one
     * here counts nothing.
     *
     * Not much of a function, which is the point rather than an
     * argument against: what it decides is what a CONFIGUREOPTS is
     * allowed to look like, and a build system that decided that
     * slightly differently would be a build system whose options are
     * spelled slightly differently for no reason anybody could
     * explain. */
    static std::string option_value(const std::string& opt,
                                    const std::string& flag);

    /* What one of the --depend paths actually names.  A path that
     * turns out to be another vendored tree in this run becomes that
     * tree's stamp rather than its directory, which is the difference
     * between "wait for it to be built" and "wait for the directory
     * to change" -- and only the first of those is what anybody
     * means.
     *
     * "peers" is the trees this same project vendored, and only
     * those: targets are generated at the end of every project, so a
     * tree some other project pulled in was never in the list and
     * gets the same answer a typo does.  Within one project the order
     * doesn't matter, since every SUBPROJECTS has been read before
     * any of this runs.
     *
     * This is here rather than in each build system because a
     * --depend is one question with one answer, and the answer is
     * mostly a set of refusals: a path that names the tree that wrote
     * it, one that climbs out of the project, one that names a
     * pconfigure subproject rather than a vendored tree.  Four copies
     * of a diagnostic are four diagnostics that have not drifted
     * apart yet, and the one thing worse than a build system with a
     * bad error message is two build systems with different bad error
     * messages for the same mistake.
     *
     * Whether the path may be named at all is checked_project_path()'s
     * question rather than this one's, which is what keeps the answer
     * the same as every other Configfile-written path's.  What is
     * left here is what a --depend actually names. */
    std::string resolve_depend(
        const std::string& flag,
        const std::string& path,
        const std::vector<ptr>& peers) const;

public:
    /* Points a copy of this build system at a directory, which is
     * what a SUBPROJECTS does once it's worked out who should build
     * it.  Copying rather than binding in place is what keeps one
     * subproject's CONFIGUREOPTS off another's. */
    ptr bind(const std::string& base, const context::ptr& context) const;

public:
    /* The build system with the given name, or NULL when there isn't
     * one, along with the list of names for saying so. */
    static ptr create(const std::string& name);
    static std::vector<std::string> names(void);

    /* The first character in "written" that a shell -- or make's own
     * recipe line, which a shell reads in turn -- treats specially
     * wherever it appears, needing no space on either side to do it:
     * ';', '&' and '|' end one command and start another, '`', '('
     * and ')' run a command of their own, '<' and '>' redirect
     * whatever runs beside them, and a newline is a second line no
     * Configfile line was ever written to have.  "" when "written"
     * has none of them.
     *
     * A path in a Configfile is never legitimately any of these --
     * unlike a '/', a '.' or a '-', nothing here spells a real
     * directory with one in it -- so refusing the character costs
     * nothing anyone meant to write.
     *
     * This is public and static, rather than living next to
     * checked_project_path() below where the rest of what a path may
     * not be is decided, because it is asked from two translation
     * units: checked_project_path() asks it of a vendored tree's own
     * paths, and command_processor's own leaves_the_project() -- a
     * different function, in a different file, asking the same
     * question of LIBDIR, SOURCES, PREFIX and everything else a
     * Configfile writes -- asks it too.  One list of characters
     * rather than two that can drift apart is the whole point: six
     * rounds of finding one more of these in one of the two checks
     * and not the other is what this function exists to stop being
     * possible. */
    static std::string unsafe_metacharacter(const std::string& written);
};

#endif
