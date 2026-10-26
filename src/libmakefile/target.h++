/*
 * Copyright (C) 2015-2016 Palmer Dabbelt
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

#ifndef LIBMAKEFILE__TARGET_HXX
#define LIBMAKEFILE__TARGET_HXX

#include "global_targets.h++"
#include "path_prefix.h++"
#include <memory>
#include <vector>
#include <string>

namespace makefile {
    /* A fully-generated Makefile target, which contains a large batch of  */
    class target {
    public:
        typedef std::shared_ptr<target> ptr;
        friend bool same_recipe(const target::ptr& a, const target::ptr& b);

    private:
        const std::string _name;
        const std::string _short_cmd;
        const std::vector<target::ptr> _deps;
        const std::vector<global_targets> _global;
        const std::vector<std::string> _cmds;
        const std::vector<std::string> _comment;

        /* TRUE for a target that is a name rather than a file, which
         * make has to be told outright: otherwise a file that happens
         * to turn up under that name stops the rule from running, and
         * a name nobody ever creates gets rebuilt every time whether
         * anything changed or not. */
        bool _phony;

        /* TRUE for a target whose output is itself a piece of
         * Makefile, which whoever writes this one has to "include" as
         * well as say how to build.
         *
         * make remakes what it includes before it reads it, which is
         * the whole reason this exists: a file that says what a source
         * depends on can be built by the same build that is about to
         * need the answer. */
        bool _included;

        /* Paths this target owns but does not build, which "make
         * clean" removes along with the target itself.
         *
         * A rule that leaves something behind under a name it was
         * never asked to produce -- scratch a test is given, say --
         * has nowhere else to say so: the clean helper is generated
         * from the target's own name, so anything not named there
         * survives a clean and accumulates until somebody goes
         * looking for what filled the disk. */
        std::vector<std::string> _clean_extra;

        /* Prerequisites that have to be made before the recipe runs
         * but that never make it due by being newer than the target,
         * which make spells after a '|'.  The recipe sees them as
         * "$|", and not as "$^". */
        std::vector<std::string> _order_only;

        /* A make expression that, expanded just before the recipe
         * would run, says whether to run none of it: anything but
         * nothing skips every line, the progress line included.
         *
         * make expands every line of a recipe before it runs the
         * first, so the answer is worked out once and the whole
         * recipe goes one way.  A target skipped this way is still
         * one make believes it has remade, which is what a caller
         * has to want: it is for a recipe that would do the wrong
         * thing now and will be asked again. */
        std::string _skip_if;

    public:
        /* Creates a new target fully-fledged target -- this is a
         * target that the Makefile actually knows how to generate. */
        target(const std::string& name,
               const std::string& short_cmd,
               const std::vector<target::ptr>& deps,
               const std::vector<global_targets>& global,
               const std::vector<std::string>& cmds,
               const std::vector<std::string>& comment);

        /* Creates a new target that the Makefile can't generate --
         * this is something that must exist in the filesystem
         * already. */
        target(const std::string& name);

	virtual ~target(void) {}

    public:
        /* Accessor methods. */
        const std::string& name(void) const { return _name; }
        const decltype(_cmds)& cmds(void) const { return _cmds; }
        const decltype(_deps)& deps(void) const { return _deps; }

    public:
        /* Returns a copy of this target without the given global target. */
        ptr without(global_targets g) const;

        /* Returns a copy of this target that make is told is a name
         * rather than a file. */
        ptr as_phony(void) const;

        /* Returns a copy of this target that whoever writes it out
         * also "include"s. */
        ptr as_included(void) const;

        /* Returns a copy of this target that "make clean" also
         * removes the given path for. */
        ptr with_clean_extra(const std::string& path) const;

        /* Returns a copy of this target with the given paths as
         * order-only prerequisites, and a recipe that runs none of
         * its lines when "skip_if" expands to anything at all. */
        ptr with_order_only(const std::vector<std::string>& paths,
                            const std::string& skip_if) const;

        bool included(void) const { return _included; }

        /* Returns TRUE if this target is a dependency of the given global
         * target. */
        bool has_global_target(const global_targets& g) const;

    public:
        /* Writes this target (and with its commands) to the given
         * file.  "check_stamp" is the name of the stamp file that
         * "make check" hangs its tests off of, which depends on which
         * project this target belongs to. */
        void write_to_file(FILE *file,
                           bool verbose,
                           const std::string& check_stamp,
                           const path_prefix& prefix) const;
    };

    /* Returns TRUE if two targets have equivilant recipes.  Note that you
     * can't rely on this doing anything between a perfect equivilance match
     * and a string comparison, since it currently does string compare but I
     * might have to extend it. */
    bool same_recipe(const target::ptr& a, const target::ptr& b);

    /* A path somebody else chose -- a file a GENERATE script printed,
     * a TESTDEPS, a CONFIG_DEPS -- spelled so that make reads it back
     * as that path when it lands bare among a rule's prerequisites.
     * The name of anything this Makefile builds never needs it, since
     * names with a '#' or a '$' are refused at the Configfile line;
     * this is for the files that are only ever read, which includes
     * every header and script include the scan finds. */
    std::string prerequisite(const std::string& path);

    /* The same path spelled as the target of a rule, which differs
     * from a prerequisite in what a '%' means. */
    std::string rule_target(const std::string& path);

    /* Why make has no way to name this path on a rule line at all, or
     * "" when prerequisite() and rule_target() can both spell it: a
     * sentence for a diagnostic, about the first such character. */
    std::string unspellable(const std::string& path);

    /* The same path spelled for the inside of a function call on a
     * rule line, "$(wildcard ...)" and the like, where make reads
     * less of it specially than it does bare. */
    std::string function_argument(const std::string& path);

    /* The same path spelled as the argument to "$(wildcard ...)",
     * which is a glob, so that it matches the file of that name and
     * nothing else. */
    std::string wildcard_argument(const std::string& path);

    /* Text for a rule line that names the file at this path as a
     * prerequisite while it exists and comes to nothing while it does
     * not: a "$(wildcard ...)" of it, or something longer for a name
     * that the bare result of that would not be read back as. */
    std::string present_prerequisite(const std::string& path);

    /* Text for a rule line that names a file this build has a rule
     * for, which it is to bring up to date while remaking the
     * Makefile, once make has read every piece of Makefile that rule
     * might be made of -- and nothing before then, or during a clean.
     * See makefile::write_to_file() for why. */
    std::string built_once_read_prerequisite(const std::string& path);

    /* The lines to write just ahead of an "include" of the file make
     * reads as "name", which note that it is not there to be read:
     * so that make, which goes on without it and makes it later,
     * knows on this pass that what it read is not the whole of it. */
    std::string note_if_unread(const std::string& name);

    /* The make variable those lines set, which is empty on a pass
     * that read every included piece of Makefile there was to read. */
    static const char *const unread_variable = "__pconfigure__unread";

    /* The make variables present_prerequisite() spells a parenthesis
     * with, which every generated Makefile defines before its first
     * rule.  Named like the rest of what the Makefile keeps for itself,
     * so that no Configfile's variable can be one of them.  Plain
     * character constants rather than strings, because this code is
     * linked into more than one of the shared libraries and a global
     * with a constructor would be built and torn down once by each. */
    static const char *const left_parenthesis = "__pconfigure__lparen";
    static const char *const right_parenthesis = "__pconfigure__rparen";
}

#endif
