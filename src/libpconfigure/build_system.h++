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
    targets(const std::vector<ptr>& peers) const;

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
    vendored_targets(const std::vector<ptr>& peers) const = 0;

    /* Takes one CONFIGUREOPTS line.  This is the half of
     * add_configureopt() that knows what an option means, and it's
     * the only half a build system has to write. */
    virtual void take_configureopt(const std::string& opt) = 0;

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
};

#endif
