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

    /* Handles one CONFIGUREOPTS line.  What an option means is up to
     * the build system it was handed to, so the line arrives here
     * exactly as it was written. */
    virtual void add_configureopt(const std::string& opt) = 0;

    /* The targets that drive this build system, which go into the
     * Makefile of the project that pulled the tree in -- a vendored
     * tree's own Makefile belongs to the tree.
     *
     * "peers" is every vendored tree the same project pulled in,
     * which is how a subproject that has to be built after another
     * one finds out what to wait for.  Nothing else about a peer is
     * any of this one's business. */
    virtual std::vector<makefile::target::ptr>
    targets(const std::vector<ptr>& peers) const = 0;

    /* The file that says this build system has been run since
     * anything it reads changed, or "" for one that hasn't got a
     * single such file.  This is what a subproject that has to wait
     * for another one hangs itself off. */
    virtual std::string build_stamp(void) const { return ""; }

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
