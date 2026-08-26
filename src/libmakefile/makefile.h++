/*
 * Copyright (C) 2015 Palmer Dabbelt
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

#ifndef LIBMAKEFILE__MAKEFILE_HXX
#define LIBMAKEFILE__MAKEFILE_HXX

#include <memory>
#include <utility>
#include <vector>
#include "path_prefix.h++"
#include "target.h++"

namespace makefile {
    /* Wraps up the data contained within a Makefile with objects so
     * you don't have to know too much about the text format of a
     * Makefile and can instead rely on simply generating some
     * objects. */
    class makefile {
    public:
        typedef std::shared_ptr<makefile> ptr;

        std::vector<target::ptr> _targets;

    private:
	    const bool _verbose;

        /* The directory that intermediate build products go into,
         * which is where the "make check" stamp and reports live. */
        const std::string _obj_dir;

        /* Dependencies that get written out on their own, without a
         * recipe attached. */
        std::vector<std::pair<std::string, std::string>> _extra_deps;

        /* Where this Makefile sits relative to whoever runs make. */
        const path_prefix _prefix;

        /* Targets that only make sense when make was run in this
         * project rather than in a parent that included it, because
         * a parent has its own. */
        std::vector<target::ptr> _standalone_targets;

        /* The Makefiles of the projects this one pulls in, along with
         * the variables that say where they are. */
        std::vector<std::pair<std::string, std::string>> _subprojects;

        /* The variables that say where the rest of the projects in
         * the run are, and what this Makefile thinks the answer is.
         * Nothing here gets included -- these are the projects this
         * one might name a path inside without knowing how to build
         * anything of theirs. */
        std::vector<std::pair<std::string, std::string>> _peers;

        /* The stamp files of those projects, which this one's stamp
         * waits on so that "make check" tests everything. */
        std::vector<std::string> _check_stamps;

        /* The directories ptest should look in for test results,
         * which is one per project. */
        std::vector<std::string> _check_dirs;

        /* The named sets of tests this Makefile can be asked to run
         * on their own, each with the test results that are in it.
         * The results are named outright rather than described,
         * because which tests are in a suite is something the
         * Configfiles said and nothing on disk records. */
        std::vector<std::pair<std::string,
                              std::vector<std::string>>> _test_suites;

        /* The one of those that "make check" runs, or empty for a
         * "make check" that means every test in the build. */
        std::string _default_test_suite;

    public:
        /* Creates a new "empty" Makefile -- note that this actually
         * contains some about of default targets and such that you
         * don't want if you're going to be */
        makefile(bool verbose = false,
                 const std::string& obj_dir = "obj",
                 const path_prefix& prefix = path_prefix());

    public:
        /* The name of the stamp file that "make check" hangs its
         * tests off of. */
        std::string check_stamp(void) const
            { return _prefix.rewrite(_obj_dir + "/check-all-done"); }

    public:
        /* Adds a target to this makefile. */
        void add_target(const target::ptr& target);

        /* Adds a dependency that isn't part of any target's recipe.
         * This is how dependencies that were worked out by looking at
         * the command lines get written down, and it's the only way
         * to make a target depend on something another Makefile knows
         * how to build. */
        void add_dep(const std::string& target, const std::string& dep);

        /* Adds a target that's only written out for a standalone
         * build.  These are the ones that carry a recipe and a name
         * that every project uses, so two of them in one make run
         * would be two recipes for the same target. */
        void add_standalone_target(const target::ptr& target);

        /* Pulls in another project's Makefile.  "base" is where that
         * project is relative to where pconfigure ran, and "variable"
         * is the make variable it uses to find itself. */
        void add_subproject(const std::string& variable,
                            const std::string& base);

        /* Says where another project in the run is, without pulling
         * its Makefile in.  This is how a project that names a path
         * belonging to a sibling gets to say where that sibling is
         * when make was run here -- and how the project make was
         * actually run in gets the last word for everybody, since
         * these are all defaults and the outermost Makefile is read
         * first. */
        void add_peer(const std::string& variable,
                      const std::string& base);

        /* Waits on another project's "make check" stamp, and looks in
         * another project's directory for test results. */
        void add_check_stamp(const std::string& stamp);
        void add_check_dir(const std::string& dir);

        /* Adds the results of one named set of tests, which get their
         * own "check-<name>" and "report-<name>" rules.  A name that
         * has already been added is added to rather than added again:
         * two projects with a suite of the same name have one suite
         * as far as make is concerned, since there is one rule with
         * that name to run. */
        void add_test_suite(const std::string& name,
                            const std::vector<std::string>& results);

        /* Points "make check" and "make report" at one of those
         * rather than at every test in the build. */
        void set_default_test_suite(const std::string& name);

        /* Writes this makefilie out to a text file. */
        void write_to_file(const std::string& filename);
    };
}

#endif
