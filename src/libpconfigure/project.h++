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

    /* The SUBPROJECTS (or BOOTSTRAP) line that pulled this project
     * in, or NULL for the project pconfigure was run in.  A project
     * that two lines ask for is read for the first of them, so that
     * is the one it remembers. */
    const command::ptr _asked_by;

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
            const command_processor::ptr& processor,
            const command::ptr& asked_by);
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
     * pulled it in, and is NULL for the project being configured.
     * "asked_by" is the line that pulled it in. */
    static ptr read(const std::string& base,
                    const context::ptr& defaults,
                    const command::ptr& asked_by,
                    std::set<std::string>& seen);

    /* The same thing, for a project whose command processor already
     * exists because the command line had to be processed first. */
    static ptr read(const command_processor::ptr& processor,
                    std::set<std::string>& seen,
                    const command::ptr& asked_by = NULL);

    /* Turns a path into the one spelling of it that this run will
     * use, so that a project asked for as "./sub" and as "sub" is
     * understood to be the same project.  The result ends with a '/',
     * or is empty for the top of the tree. */
    static std::string normalize_base(const std::string& path);

    /* The make variable this project's Makefile uses to find itself,
     * which has to be unique across the whole run. */
    static std::string prefix_variable(const std::string& base);

    /* Complains if two projects in the run come out with the same
     * prefix_variable(), which directories that differ only in their
     * punctuation do.  "everyone" is every project in the run, since
     * the variable has to be unique across all of them. */
    static void check_prefix_variables(const std::vector<ptr>& everyone);

    /* The part of a generated file's name that says which project in
     * the run wrote it: the directory it sits in, with the separators
     * turned into dots, so "src/pconfigure/" is "src.pconfigure".
     * Empty for the project make gets run in, which has no directory
     * and needs no telling apart.
     *
     * This is on the name of every file a configure writes for a
     * build to read, and that is what lets a tree be configured both
     * from above and from inside it.  The two runs write into the one
     * object directory and describe the same sources, but they
     * describe them from different places -- a path that starts at
     * the top of the tree against one that starts here -- so a file
     * they shared would be a file whichever of them ran last had
     * quietly rewritten for the other.  Spelling the writer into the
     * name is what makes them two files instead of one.
     *
     * What they do share is everything a build produces: the objects,
     * the libraries, the binaries.  Those are the same answer worked
     * out from two vantage points, so sharing them is the point
     * rather than a hazard. */
    static std::string base_suffix(const std::string& base);

public:
    /* Accessor methods. */
    const std::string& base(void) const { return _base; }
    const command::ptr& asked_by(void) const { return _asked_by; }
    const std::vector<ptr>& children(void) const { return _children; }
    const command_processor::ptr& processor(void) const { return _processor; }
    const std::vector<makefile::target::ptr>& targets(void) const
        { return _targets; }
    const std::vector<makefile::capability>& provided(void) const
        { return _provided; }
    const std::vector<makefile::capability>& needed(void) const
        { return _needed; }

    /* The Makefile this project gets written to.  A project that
     * bootstraps its own pconfigure keeps the Makefile make is run at
     * in revision control, so the one pconfigure writes goes beside
     * it under another name and is included by it. */
    std::string makefile_path(void) const;

    /* The same file, spelled the way a parent has to name it in an
     * "include": through the variable that says where this project
     * sits, since a parent's make is started somewhere else. */
    std::string makefile_include(void) const;

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

    /* Complains if this project's "make check" would run no tests at
     * all.  "aggregated" is the same list write_makefile gets, and for
     * the same reason: the tests a suite runs here are the tests every
     * project this Makefile is responsible for put into it. */
    void check_default_test_suite(const std::vector<ptr>& aggregated) const;

    /* Complains if a project this build is responsible for has tests
     * and never declared a suite, in a build whose "make check" means
     * one.  "aggregated" is the same list as above, for the same
     * reason.
     *
     * This is the question check_default_test_suite() asks, turned
     * around: that one looks at the default suite and asks whether
     * anything is in it, which a build whose other projects are full
     * answers "yes" to while one project's tests sit outside every
     * suite it has.  There is no symptom downstream of that.  Nothing
     * goes red, no report mentions a test it didn't run, and the
     * "make check" in the project itself -- which is where anybody
     * would look to find out whether its guards ran -- runs every one
     * of them and says they passed.
     *
     * Three shapes this is deliberately not, because each of them is
     * an answer rather than an omission.  A build with no
     * DEFAULT_TEST_SUITE runs every test it has under "make check",
     * so a project that joined no suite has lost nothing.  A project
     * that declared some suite and not the default one has said where
     * its tests go, which is its business -- a project of nothing but
     * hours-long harnesses belongs in "overnight" and in no "smoke".
     * And a project with no tests is outside every suite for a reason
     * that has nothing to do with suites, which is every vendored
     * tree a build pulls in. */
    void check_aggregated_test_suites(const std::vector<ptr>& aggregated) const;

    /* Complains if a BOOTSTRAP names a tree that doesn't build the
     * pconfigure it promised.  "everyone" is every project in the
     * run, since the tree is one of them by the time this is asked.
     *
     * The committed Makefile runs a path, and a path is all it has:
     * nothing about it says which tree was supposed to produce that
     * file, so a BOOTSTRAP pointed one directory too high or too low
     * configures and builds perfectly well and then fails, much
     * later, with a shell saying it can't find a program. */
    void check_bootstrap(const std::vector<ptr>& everyone) const;

public:
    /* Says so when the Makefile at the top of this subproject is one
     * an older pconfigure wrote.  A parent used to write that file;
     * it writes into the object directory now, so what is left up
     * there is a description of this project from a run that has
     * been superseded -- and nothing includes it any more.
     *
     * Harmless where it sits and not harmless when somebody uses it:
     * "make" in a subproject finds it, and builds out of whatever the
     * tree looked like the last time a pconfigure that old ran.  It
     * is asked of a run from the top, because that is the run that
     * has just stopped writing the file. */
    void check_stale_makefile(void) const;

public:
    /* Complains if "make distclean" in this project would remove a
     * tree that a SUBPROJECTS or a BOOTSTRAP somewhere under it
     * named.  The recipe is an "rm -rf" of every output directory,
     * and a subproject is somebody's checkout rather than output, so
     * a tree under "lib" or "bin" is one distclean away from being
     * gone.  "Under" is asked of the name and of the directory with
     * its symlinks resolved, since the recipe follows them.
     *
     * Asked of the whole run rather than at the line, because the
     * line doesn't have the answer yet: a LIBDIR below it can move
     * the library directory onto the tree, and a project that builds
     * nothing of its own has no "lib" for distclean to remove until
     * a target says otherwise.  "projects" is this project flattened,
     * which is the list its own distclean is written from. */
    void check_distclean_spares_subprojects(
        const std::vector<ptr>& projects) const;

public:
    /* Writes down what this run told each vendored tree, so that make
     * has something to compare against.  A vendored tree's rules are
     * built out of its CONFIGUREOPTS, and a rule whose recipe changed
     * is not a rule make will run again -- so the options have to
     * reach the Makefile as a file as well as as a recipe.
     *
     * Public, and called for every project before any Makefile is
     * written, because the Makefile make is run on lists every file
     * like this one that the run wrote: written along with its own
     * project's Makefile, a subproject's would come after the list
     * was already out. */
    void write_configureopts(void) const;

public:
    /* A project and everything below it, parents before children. */
    static std::vector<ptr> flatten(const ptr& root);

public:
    /* Which of this project's tests each of its suites runs, named by
     * the target that runs them.  Every suite the project declared is
     * in here, including the ones nothing joined: a suite is a promise
     * about what a name means, and an empty one keeps it.
     *
     * A test is in a suite because it said so, because a suite this
     * one includes has it, because a test that is in the suite waits
     * for it, or because it was written without a suite and every
     * test it waits for is in this one.  The third of those isn't a
     * choice: make builds what a DEPTESTS names before it runs the
     * test that waits, so a suite that left it out would be reporting
     * on a smaller run than the one that happened. */
    std::map<std::string, std::vector<std::string>>
    test_suite_members(void) const;

    /* The same question asked of a whole build: which tests each
     * suite runs, across every project whose results one Makefile is
     * responsible for.  "aggregated" is the list write_makefile gets,
     * and the answer is what its suite rules hang their tests off.
     *
     * This is not the union of the per-project answers, which is why
     * it exists.  A suite of one name is one suite here -- one rule,
     * with one set of prerequisites -- so a suite that includes
     * another runs every test of that name in the build, not just
     * the ones that happen to live beside the line that said so.  A
     * subproject's test that joined "smoke" is in the parent's
     * "overnight" for the same reason it is in the parent's "smoke":
     * there is one "smoke" here, and "overnight" was told it runs
     * it. */
    static std::map<std::string, std::vector<std::string>>
    aggregate_test_suite_members(const std::vector<ptr>& aggregated);

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

    /* Every directory "make distclean" removes whole for these
     * projects, each mapped to a few words saying what the build
     * puts there.  The recipe is written from this and so is the
     * check that no subproject sits under one of them, so the two
     * can't come to disagree about what the recipe reaches. */
    static std::map<std::string, std::string>
    distclean_dirs(const std::vector<ptr>& projects);

    /* Writes down where the test results this project is responsible
     * for end up, so that "ptest" run on its own can find them.  The
     * Makefile knows this already -- it's the same list its report
     * rules hand along -- but a report you can only get by running
     * make is no use on a build that doesn't build. */
    void write_check_dirs(const std::vector<ptr>& aggregated) const;

    /* Writes down which stamp "make check" builds here, for the same
     * reason and to be read by the same program: "ptest" run on its
     * own says whether the results it is reporting are current, and
     * the file it has to ask make about is the one this project's
     * "make check" actually builds. */
    void write_check_stamp(void) const;

    /* Writes down which test results each of the Makefile's "make
     * check" stamps stands for, in the files those stamps wait on
     * (see makefile::check_scopes()).  Only a file whose contents
     * changed is written, since a file rewritten on every configure
     * would have every "make check" score everything again. */
    void write_check_scopes(const makefile::makefile& out) const;

    /* Writes the Makefile that a BOOTSTRAP project commits, which is
     * the one make is actually run at.
     *
     * Everything in it comes from the BOOTSTRAP line, so it says the
     * same thing today that it said when it was written down: how to
     * get a pconfigure out of the vendored source, and where to find
     * the Makefile that pconfigure writes.  That's what makes it
     * worth keeping -- a file that changed every time the build did
     * would be a generated file in revision control, which is a merge
     * conflict waiting to happen. */
    void write_bootstrap_makefile(void) const;

    /* Says so when a target isn't shaped like one: nothing to build,
     * or the same output as something already asked for.  Both are
     * things that come out looking like they worked. */
    static void check_target_shape(const context::ptr& ctx,
                                   std::map<std::string, context::ptr>& seen);

    /* Refuses a GENERATE whose output is one of the files another
     * GENERATE keeps beside its own -- the temporary its output is
     * written through, its dependency fragment and that fragment's
     * leftovers -- or whose own such files are another GENERATE's
     * output.  "claimed" maps each of those paths to the line that
     * claimed it and what the path is to that line. */
    static void check_generate_names(
        const context::ptr& ctx,
        std::map<std::string,
                 std::pair<context::ptr, std::string>>& claimed);

    /* Every test this project runs, by the name of the target that
     * runs it -- which is what a DEPTESTS resolves to, and what a
     * suite's rule hangs its tests off.
     *
     * A test is a child of the thing it exercises rather than an
     * output context of its own, so this has to go down and look:
     * asking only the contexts at the top finds no tests at all. */
    std::map<std::string, context::ptr> tests(void) const;

    /* Says so when an INCLUDE_TEST_SUITES or a TESTS names a suite
     * this project
     * never declared.  It's asked here rather than where the line was
     * read because a suite is allowed to be named by a line above the
     * one that declares it: the suites of a project are a set, and
     * nothing about them depends on the order the file happens to
     * name them in. */
    void check_test_suites(void) const;

    /* Says so when the DEPTESTS in this project don't describe an
     * order any run of the tests could take: one that waits for a
     * test nobody wrote, or a set of them that waits in a circle.
     * make has an answer for both -- "No rule to make target" for the
     * first, and quietly dropping an edge for the second -- and
     * neither answer names the Configfile line that caused it. */
    void check_test_order(void) const;

    /* Says so when an AUTODEPS = false reached nothing that links,
     * which is the only thing turning it off was ever meant to
     * change.  What's left is a set of targets that have stopped
     * being rebuilt when what they include changes, in exchange for
     * nothing at all. */
    void check_autodeps(void) const;
};

#endif
