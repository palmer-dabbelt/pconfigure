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

#ifndef PROJECT_HXX
#define PROJECT_HXX

#include "command_processor.h++"
#include "commands.h++"
#include <libmakefile/implied_deps.h++>
#include <libmakefile/makefile.h++>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <vector>

/* Everything that comes out of one project's Configfiles: the targets
 * they describe, what those targets offer each other, and the Makefile
 * they all get written to.
 *
 * A pconfigure run has one of these per project, so there's nothing
 * here that a second project in the same run would trip over. */
class project {
public:
    typedef std::shared_ptr<project> ptr;

private:
    const std::string _base;
    const command_processor::ptr _processor;

    /* The targets, in the order they were generated -- which is the
     * order they get written out in, so it has to be stable. */
    std::vector<makefile::target::ptr> _targets;
    std::map<std::string, makefile::target::ptr> _by_name;

    std::vector<makefile::capability> _provided;
    std::vector<makefile::capability> _needed;

    /* The projects this one pulled in with SUBPROJECTS. */
    std::vector<ptr> _children;

public:
    project(const std::string& base,
            const command_processor::ptr& processor);
    virtual ~project(void) {}

public:
    /* Reads a project and everything it pulls in, turning all of it
     * into targets.
     *
     * A subproject is read at the point its SUBPROJECTS command shows
     * up rather than afterwards, so that the rest of the Configfile
     * that asked for it can refer to what it builds.  "seen" is
     * carried through the whole run so that a project that gets asked
     * for twice is only read once, and so that a project that somehow
     * contains itself doesn't recurse forever.
     *
     * "defaults" is the context a subproject inherits from whoever
     * pulled it in, and is NULL for the project being configured. */
    static ptr read(const std::string& base,
                    const context::ptr& defaults,
                    std::set<std::string>& seen);

    /* The same thing, for a project whose command processor already
     * exists because the command line had to be processed first. */
    static ptr read(const command_processor::ptr& processor,
                    std::set<std::string>& seen);

    /* Turns a path into the one spelling of it that this run will
     * use, so that a project asked for as "./sub" and as "sub" is
     * understood to be the same project.  The result ends with a '/',
     * or is empty for the top of the tree. */
    static std::string normalize_base(const std::string& path);

    /* The make variable this project's Makefile uses to find itself,
     * which has to be unique across the whole run. */
    static std::string prefix_variable(const std::string& base);

public:
    /* Accessor methods. */
    const std::string& base(void) const { return _base; }
    const std::vector<ptr>& children(void) const { return _children; }
    const command_processor::ptr& processor(void) const { return _processor; }
    const std::vector<makefile::target::ptr>& targets(void) const
        { return _targets; }
    const std::vector<makefile::capability>& provided(void) const
        { return _provided; }
    const std::vector<makefile::capability>& needed(void) const
        { return _needed; }

    /* The Makefile this project gets written to. */
    std::string makefile_path(void) const { return _base + "Makefile"; }

public:
    /* Turns this project's contexts into targets, asking each
     * context's language what its targets offer and want along the
     * way. */
    void generate_targets(void);

    /* Writes this project's Makefile.  "implied" is the dependencies
     * that belong in this Makefile, "aggregated" is every project
     * whose test results and build directories this one's Makefile is
     * responsible for -- which is all of them for the project make
     * gets run in, and none of them for a project that only ever gets
     * included -- and "everyone" is every project in the run, which
     * is how a path belonging to a project this one has never heard
     * of still gets written down in terms of that project. */
    void write_makefile(const std::vector<makefile::implied_dep>& implied,
                        const std::vector<ptr>& aggregated,
                        const std::vector<ptr>& everyone) const;

    /* The projects this one pulls in, at any depth, including
     * itself. */
    std::set<std::string> reachable(void) const;

public:
    /* A project and everything below it, parents before children. */
    static std::vector<ptr> flatten(const ptr& root);

private:
    /* Processes one Configfile line and everything it asks for: a
     * CONFIG is read where it appears, and a SUBPROJECTS is read
     * before the next line, so that the rest of the file can refer to
     * what the subproject builds. */
    static void process_line(const ptr& self,
                             const configfile_line& line,
                             std::set<std::string>& seen);

    /* Processes every line of one Configfile. */
    static void read_file(const ptr& self,
                          const std::string& filename,
                          std::set<std::string>& seen);

    /* The targets that don't come from any context: cleaning out the
     * object cache, and undoing a configure. */
    makefile::target::ptr cache_clean_target(const std::vector<ptr>& projects) const;
    makefile::target::ptr distclean_target(const std::vector<ptr>& projects) const;

    /* Writes down where the test results this project is responsible
     * for end up, so that "ptest" run on its own can find them.  The
     * Makefile knows this already -- it's the same list its report
     * rules hand along -- but a report you can only get by running
     * make is no use on a build that doesn't build. */
    void write_check_dirs(const std::vector<ptr>& aggregated) const;

    /* Writes down what this run told each vendored tree, so that make
     * has something to compare against.  A vendored tree's rules are
     * built out of its CONFIGUREOPTS, and a rule whose recipe changed
     * is not a rule make will run again -- so the options have to
     * reach the Makefile as a file as well as as a recipe. */
    void write_configureopts(void) const;

    /* Says so when a target isn't shaped like one: nothing to build,
     * or the same output as something already asked for.  Both are
     * things that come out looking like they worked. */
    static void check_target_shape(const context::ptr& ctx,
                                   std::map<std::string, context::ptr>& seen);

    /* Says so when the DEPTESTS in this project don't describe an
     * order any run of the tests could take: one that waits for a
     * test nobody wrote, or a set of them that waits in a circle.
     * make has an answer for both -- "No rule to make target" for the
     * first, and quietly dropping an edge for the second -- and
     * neither answer names the Configfile line that caused it. */
    void check_test_order(void) const;
};

#endif
