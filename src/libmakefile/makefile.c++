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

#include "makefile.h++"
#include "self_path.h++"
#include <algorithm>
#include <iostream>

/* Writes one "check-report" rule.  There are four of them -- the quiet
 * and loud reports a project always has, and the same pair again for
 * every named test suite -- and they are one recipe, so they are
 * written from one place.  That is not tidiness: the recipe has
 * acquired its shape a piece at a time, and a piece added to two of
 * the four copies is a tree where "make check" keeps a promise that
 * "make check-smoke" does not, which nothing in the generated Makefile
 * makes visible.
 *
 * A report is read off the disk at least as often as it is read out of
 * "make report" -- by a person looking at what last night did, by a
 * script, by anything that writes a run up afterwards.  So a scoring
 * that fails takes the report with it rather than leaving the one the
 * last passing run wrote: a file that says NFAIL 0 about a run that
 * failed gets believed, and it is believed precisely when somebody has
 * stopped watching make's output, which is the moment the file is all
 * there is.  The quiet report is the worse half of this, not the lesser
 * one -- a passing quiet run prints nothing, so its report is an empty
 * file, and a stale one is byte for byte what a fresh one would have
 * been.  The rule this recipe keeps is that a report exists if and only
 * if the last scoring of it passed, which leaves absence as the one
 * state a reader cannot misread.
 *
 * The "rm -f $@" is what makes that "only if" hold when the scoring
 * neither passes nor fails, which is the common way for an overnight
 * run to end: somebody hits ^C, a job timeout fires, the machine goes
 * down.  The "||" arm covers a scorer that exited nonzero and nothing
 * else -- kill the recipe's shell and no arm runs at all, "$@" is
 * never touched, and the PREVIOUS run's report is still sitting there
 * looking exactly like a fresh one, with the mtime of the run it
 * really did describe.  make's own interrupt handling does not close
 * this: it deletes the target of the recipe it was running only if
 * that recipe had changed the file, and this one writes "$@.tmp"
 * until the very last step, so there is nothing for make to decide to
 * delete.  SIGKILL gets no handler either way.
 *
 * Clearing it up front instead means the window in which the report
 * is wrong is replaced by a window in which it is absent, and absent
 * is the state the rest of this recipe has already arranged to be
 * unmisreadable.  It costs a report that was good while the next
 * scoring runs, which is a few seconds of a file nobody is reading
 * yet, and it cannot leave a report newer than its stamp.
 *
 * The detail still comes out, on stdout, through "cat $@.tmp": what ran
 * is in the result tarballs under the check directories either way, so
 * asking again re-scores them in seconds without re-running a single
 * test.  A file kept beside the report would only be a second thing to
 * go stale, and one asserting a failure at that.
 *
 * Writing the report out anyway and then exiting 1 is the shape to
 * avoid, however much more honest the file looks: it leaves the report
 * newer than the stamp it was made from, so the next "make report" has
 * nothing to do and exits 0 with the tests still red.  Nothing here may
 * leave a report newer than its stamp.  ".DELETE_ON_ERROR:" is not this
 * either -- make deletes a failed recipe's target only when the recipe
 * changed it, and "&&" means this one never got as far as the mv -- and
 * it is file-global, so it would start removing half-written targets
 * for every other rule in the Makefile besides. */
static void write_report_rule(FILE *file,
                              const std::string& report,
                              const std::string& stamp,
                              const char *quiet_make,
                              const std::string& ptest,
                              bool quiet,
                              const std::string& args)
{
    fprintf(file,
            "%s: %s\n\t%srm -f $@ && %s%s --no-check-make-check%s"
            " > $@.tmp && mv $@.tmp $@"
            " || (cat $@.tmp; rm -f $@.tmp $@; exit 1)\n\n",
            report.c_str(), stamp.c_str(), quiet_make, ptest.c_str(),
            quiet ? " --quiet" : "", args.c_str());
}

makefile::makefile::makefile(bool verbose,
                             const std::string& obj_dir,
                             const path_prefix& prefix)
: _verbose(verbose),
  _obj_dir(obj_dir),
  _prefix(prefix),
  _write_reconfigure(true),
  _pconfigure_args(),
  _record_pconfigure_args(false)
{
}

void makefile::makefile::add_target(const target::ptr& target)
{
    _targets.push_back(target);
}

void makefile::makefile::add_dep(const std::string& target,
                                 const std::string& dep)
{
    _extra_deps.push_back(std::make_pair(target, dep));
}

void makefile::makefile::add_standalone_target(const target::ptr& target)
{
    _standalone_targets.push_back(target);
}

void makefile::makefile::add_subproject(const std::string& variable,
                                        const std::string& base,
                                        const std::string& path)
{
    _subprojects.push_back(subproject{variable, base, path});
}

void makefile::makefile::add_peer(const std::string& variable,
                                  const std::string& base)
{
    _peers.push_back(std::make_pair(variable, base));
}

void makefile::makefile::add_check_stamp(const std::string& stamp)
{
    _check_stamps.push_back(stamp);
}

void makefile::makefile::add_check_dir(const std::string& dir,
                                       bool abrt_is_fail)
{
    _check_dirs.push_back(std::make_pair(dir, abrt_is_fail));
}

void makefile::makefile::add_test_suite(const std::string& name,
                                        const std::vector<std::string>& results)
{
    for (auto& suite: _test_suites) {
        if (suite.first != name)
            continue;

        for (const auto& result: results)
            suite.second.push_back(result);
        return;
    }

    _test_suites.push_back(std::make_pair(name, results));
}

void makefile::makefile::set_default_test_suite(const std::string& name)
{
    _default_test_suite = name;
}

void makefile::makefile::skip_reconfigure(void)
{
    _write_reconfigure = false;
}

void makefile::makefile::rerun_with(const std::string& args)
{
    _pconfigure_args = args;
    _record_pconfigure_args = true;
}

void makefile::makefile::reconfigure_on(
    const std::vector<std::string>& configfiles,
    const std::vector<std::string>& built)
{
    _configfiles = configfiles;
    _configfiles_built = built;
}

void makefile::makefile::restore_configure_outputs(
    const std::map<std::string, std::string>& outputs)
{
    _configure_outputs = outputs;
}

/* A word the shell reads back as exactly these bytes, inside a recipe
 * make hands it: single quotes for the shell, with the one character
 * they can't hold closed around, and every '$' doubled for make --
 * which expands a recipe before the shell ever sees it, quotes or
 * not. */
static std::string recipe_quoted(const std::string& text)
{
    auto out = std::string("'");
    for (const auto c: text) {
        if (c == '\'')
            out += "'\\''";
        else if (c == '$')
            out += "$$";
        else
            out += c;
    }
    return out + "'";
}

/* How much of a file one recipe line writes.  make runs each recipe
 * line as a single argument to the shell, and Linux refuses an exec
 * whose one argument is over 128 KiB (MAX_ARG_STRLEN), whatever the
 * total limit is; a deps-context has a line per source, so a binary
 * with a few hundred long-named ones is past that.  This counts the
 * quoted text, before make turns "$$" back into "$", and stays well
 * under, leaving room for the printf and the path make puts in for
 * "$@". */
static const size_t write_recipe_line_limit = 32 * 1024;

/* The recipe lines that write a file holding exactly "contents".  A
 * recipe line is one line of make and the contents are several, so
 * each line goes to printf as an argument of its own, and printf puts
 * the newlines back; whatever follows the last newline is printed
 * without one.  Lines are gathered into as few printfs as fit under
 * write_recipe_line_limit, the first writing the file and the rest
 * appending to it, and a single line too long for one goes out in
 * pieces with its newline after.
 *
 * Through a temporary and a rename, so that a make interrupted half
 * way through leaves no file at all rather than a short one -- which
 * make would go on believing, since a file with no prerequisites is
 * up to date for as long as it exists.  The first line truncates the
 * temporary, so one left over from such a make does no harm. */
static std::vector<std::string> write_recipe(const std::string& contents)
{
    auto lines = std::vector<std::string>();
    auto tail = std::string();
    for (const auto c: contents) {
        if (c == '\n') {
            lines.push_back(tail);
            tail.clear();
        } else {
            tail += c;
        }
    }

    /* Each command here is one printf, of a size that fits on a
     * recipe line of its own. */
    auto commands = std::vector<std::string>();
    auto pending = std::string();
    auto flush = [&]() {
        if (pending.size() > 0)
            commands.push_back("printf '%s\\n'" + pending);
        pending.clear();
    };

    /* A piece of raw text quotes to at most four times its size, a
     * "'" turning into four characters, so pieces this long always
     * fit. */
    const auto piece = write_recipe_line_limit / 4;
    auto print_unterminated = [&](const std::string& text) {
        for (size_t i = 0; i < text.size(); i += piece)
            commands.push_back("printf '%s' " +
                               recipe_quoted(text.substr(i, piece)));
    };

    for (const auto& line: lines) {
        auto word = " " + recipe_quoted(line);
        if (word.size() > write_recipe_line_limit) {
            flush();
            print_unterminated(line);
            commands.push_back("printf '\\n'");
            continue;
        }
        if (pending.size() + word.size() > write_recipe_line_limit)
            flush();
        pending += word;
    }
    flush();
    print_unterminated(tail);

    auto out = std::vector<std::string>();
    if (commands.size() == 0)
        out.push_back(": > $@.tmp");
    for (const auto& command: commands)
        out.push_back(command + (out.size() == 0 ? " > $@.tmp" : " >> $@.tmp"));
    out.push_back("mv -f $@.tmp $@");
    return out;
}

void makefile::makefile::write_to_file(const std::string& filename)
{
    /* Rewritten every time, unconditionally, and that is not an
     * oversight left over from before file_utils::write_if_changed()
     * existed.  It is what stops the reconfigure loop.
     *
     * This file is a makefile make included, and down at the bottom it
     * is given a rule naming the Configfiles it was written out of,
     * whose recipe runs pconfigure.  make remakes the makefiles it read
     * before it uses them, so a Configfile somebody edited is a
     * Configfile that gets a pconfigure run out of it -- and the only
     * thing that then says the edit has been dealt with is this file
     * coming back newer than the Configfile.  Write it only when its
     * contents changed and an edit that does not change the generated
     * Makefile -- a comment, a reordering, a setting that resolves to
     * what it already was -- leaves a Configfile permanently newer than
     * its target.  Every make from then on reconfigures, finds nothing
     * to write, and hands back a target still older than its
     * prerequisite.  Not a loop within one make, which remakes a given
     * makefile once and gives up: a full reconfigure on every single
     * build, forever, and the tree never settles again.
     *
     * The file_utils::write_if_changed() one function away in
     * project::write_bootstrap_makefile() is the opposite case, and it
     * is right there for the opposite reason: nothing gives that file
     * prerequisites, so no timestamp is waiting on it, and it is the
     * file make was started on -- rewriting it on every configure would
     * hand make a Makefile newer than everything it had just built, and
     * would turn up as a diff in every commit that touched a
     * Configfile.  The two sit close enough together to read as an
     * inconsistency.  They are not one. */
    auto file = fopen(filename.c_str(), "w");
    if (file == NULL) {
        std::cerr << "Unable to open " << filename << "\n";
        abort();
    }

    fprintf(file, "SHELL=/bin/bash\n\n");

    /* make hands its own environment to every recipe, and a CDPATH
     * from the shell make was started in turns the recipes' relative
     * cds -- into a subproject to run its GENERATE script, into a
     * vendored tree to bootstrap or configure it -- into lookups
     * along that path.  The cd can then land in some other directory
     * of the same name, and when it uses an entry at all it prints
     * where it went, which for a GENERATE is the first line of the
     * file being generated.  Keeping it out of the recipes is what
     * pconfigure does for its own shells too, and why is said at the
     * top of main() in pconfigure++.c++.
     *
     * unexport rather than an empty assignment, so that what a
     * recipe sees is the variable not being there at all -- which is
     * what a shell that was never given one sees -- and so that it is
     * not passed down into the builds of vendored trees either. */
    fprintf(file, "unexport CDPATH\n\n");

    /* GNU make ships pattern rules that build a program out of a
     * source file sitting next to it, and they fire on any
     * prerequisite that has no rule of its own.  A generated Makefile
     * says what builds what, so one of these firing is never the
     * right answer -- it means pconfigure was asked for a file it
     * wrote no rule for, and the useful outcome there is the error
     * that says so.
     *
     * What they do instead is silent.  Buildroot keeps an
     * arch/Config.in.sh next to its arch/Config.in -- the kconfig for
     * SuperH, whose Buildroot name is "sh", and not a shell script --
     * and "%: %.sh" happily overwrites the second with the first.
     * The build that follows configures with no target architecture
     * and dies minutes later on a cross compiler called
     * "/-linux-gcc", which is a sentence about a toolchain in a tree
     * that never asked for one.
     *
     * A pattern rule with no recipe cancels the built-in of the same
     * name, and unlike --no-builtin-rules it stays in this Makefile
     * rather than riding MAKEFLAGS down into every vendored build
     * system underneath it. */
    for (const auto& suffix: {"c", "C", "cc", "cpp", "f", "F", "m",
                              "mod", "o", "p", "r", "s", "S", "sh"})
        fprintf(file, "%%: %%.%s\n", suffix);

    /* The same for the RCS and SCCS rules, which are match-anything
     * rules rather than suffix ones: they are cancelled by spelling
     * them with the double colon they were declared with. */
    fprintf(file, "%%:: %%,v\n");
    fprintf(file, "%%:: RCS/%%,v\n");
    fprintf(file, "%%:: RCS/%%\n");
    fprintf(file, "%%:: s.%%\n");
    fprintf(file, "%%:: SCCS/s.%%\n");

    /* And the old-style suffix rules, which are a separate mechanism
     * from pattern rules and are turned off by emptying the list of
     * suffixes they are built out of. */
    fprintf(file, ".SUFFIXES:\n\n");

    /* The C and C++ recipes name their compilers as ${CC} and ${CXX},
     * and archive with ${AR}, so that whoever runs make can pick the
     * toolchain -- but nothing defined them except make's own
     * built-in variables.  "make -R" takes those away, and so does a
     * parent build with -R in its MAKEFLAGS, the way kbuild runs
     * everything underneath it.  The recipe line then expands to one
     * starting with "-x c", and make reads a leading '-' on an
     * expanded recipe line as "ignore errors": the compile fails,
     * make says "(ignored)", nothing relinks, and the build exits 0
     * with the program from before the edit still in bin/.
     *
     * "?=" is what keeps them defaults rather than settings.  A CC on
     * make's command line or in the environment is still the one
     * that runs, and without -R make's built-in is already defined,
     * so this changes nothing for a build that wasn't broken.  The
     * values are the names a Unix toolchain answers to whoever made
     * it; CXX's "c++" rather than GNU make's "g++" only ever shows up
     * where GNU make's default is gone.
     * A CROSS_COMPILE names its toolchain outright and never reads
     * these at all. */
    fprintf(file, "CC ?= cc\n");
    fprintf(file, "CXX ?= c++\n");
    fprintf(file, "AR ?= ar\n\n");

    /* A project that a parent can include finds itself through a
     * variable, which is empty when make is run here and set by the
     * parent when it isn't.  Everything below is written in terms of
     * it, so it has to come first. */
    if (_prefix.included() == true)
        fprintf(file, "%s ?=\n\n", _prefix.variable().c_str());

    fprintf(file, ".PHONY: all\n");
    fprintf(file, ".PHONY: clean\n");
    fprintf(file, ".PHONY: cache-clean\n");
    fprintf(file, ".PHONY: report\n");
    fprintf(file, ".PHONY: install\n");
    fprintf(file, ".PHONY: uninstall\n");
    fprintf(file, "all:\n\n");

    /* Every installed file is a target named "$(DESTDIR)/" + prefix +
     * the file, and every uninstall is a rule named after one.  A
     * target name is a word of make, though, and make splits it where
     * the expanded DESTDIR has whitespace: "make DESTDIR='stage dir'
     * install" made a target "stage" and a target
     * "dir//usr/local/bin/x", so the install landed in a "dir" in the
     * middle of the source tree and the uninstall ran "rm -f" on both
     * halves.  Nothing says so -- it just goes somewhere else.
     *
     * DESTDIR comes from make's command line or the environment,
     * long after pconfigure ran, so this is the only place it can be
     * checked.  Escaping it into the target names isn't on offer:
     * make has no quoting that survives being expanded out of a
     * variable into a rule, and "$@" in the recipes would come out
     * unquoted anyway.
     * Not naming the installed files as targets would trade away
     * installs that only copy what changed for a corner case with a
     * one-line workaround, which is what the error says to do: a
     * symlink to the staging directory names the same place without
     * the space.
     *
     * It is checked whatever is being built rather than only for
     * "install": the split rules are in this Makefile as soon as it
     * is read, and a goal like "dir//usr/local/bin/x" reaches them
     * without the word "install" ever being said.  The "x"s on
     * either side catch a DESTDIR that is nothing but a trailing or
     * leading space, which splits just the same.  A subproject's
     * Makefile carries the same check, and the first one read is the
     * one that stops make. */
    fprintf(file, "ifneq ($(word 2,x$(DESTDIR)x),)\n");
    fprintf(file, "$(error DESTDIR=\"$(DESTDIR)\" has whitespace in it,"
                  " and make splits the installed files' target names"
                  " there: install through a path to the same directory"
                  " that has none, such as a symlink to it)\n");
    fprintf(file, "endif\n\n");

    /* Whitespace isn't the only thing make reads in a target name.  A
     * ':' ends the targets of a rule and a ';' ends its
     * prerequisites, so a DESTDIR of "stage-12:30" stopped make on
     * "target pattern contains no '%'" and one with a ';' on "missing
     * separator" -- errors about a line of this Makefile that never
     * mention DESTDIR.  A '%' is worse, because it doesn't stop
     * anything: it turns every installed file's rule into a pattern
     * rule.  The install happened to still match those, but the
     * uninstall helpers are phony, make never looks for a pattern
     * rule for a phony target, and "make uninstall" said "Nothing to
     * be done" and left everything installed.
     *
     * Each of these is an ordinary character in a directory name, so
     * the error has the same way out the whitespace one does.  A '#'
     * isn't here because it is harmless: a DESTDIR is expanded after
     * make has already stripped the comments from a line. */
    fprintf(file, "ifneq ($(findstring :,$(DESTDIR))$(findstring ;,$(DESTDIR))"
                  "$(findstring %%,$(DESTDIR)),)\n");
    fprintf(file, "$(error DESTDIR=\"$(DESTDIR)\" has a ':', ';' or '%%'"
                  " in it, and make reads those as rule syntax in the"
                  " installed files' target names: install through a path"
                  " to the same directory that has none, such as a"
                  " symlink to it)\n");
    fprintf(file, "endif\n\n");

    /* Where every other project in the run is.  These are defaults,
     * so the first Makefile make reads is the one that decides -- and
     * that's the project make was run in, which is exactly whose
     * answer is right.  All of them are written before any include so
     * that a subproject's own defaults never get in first: a
     * subproject knows where its siblings are relative to itself, and
     * that isn't the answer when the build started above it. */
    for (const auto& peer: _peers)
        fprintf(file, "%s ?= %s\n", peer.first.c_str(), peer.second.c_str());
    for (const auto& subproject: _subprojects)
        fprintf(file, "%s ?= %s\n",
                subproject.variable.c_str(),
                _prefix.rewrite(subproject.base).c_str());
    if (_peers.size() > 0 || _subprojects.size() > 0)
        fprintf(file, "\n");

    /* The subprojects come after "all" so that it stays the rule make
     * picks when it isn't told what to build, and before everything
     * else so that a subproject's rules are in hand by the time
     * anything here refers to them. */
    for (const auto& subproject: _subprojects)
        fprintf(file, "include %s\n\n", subproject.path.c_str());

    /* The targets that are themselves pieces of Makefile, which have
     * to be included as well as built.  make remakes what it includes
     * before it reads it, so a fragment that says what a source
     * depends on is written by the same run of make that is about to
     * need the answer -- and then make starts again, with the answer
     * in hand.
     *
     * The guard is what stops that going round in a circle.  A
     * fragment names the fragments of the sources behind its headers,
     * and two sources that include each other's headers describe a
     * loop; whoever is about to include one says so first, so the
     * second time round there is nothing left to do.  Both halves of
     * that are spelled the same way here and in pdeps, because they
     * are the same variable.
     *
     * These come before the rules rather than after out of
     * politeness: nothing depends on the order, since what a fragment
     * adds is prerequisites, and make collects those from wherever it
     * finds them. */
    for (const auto& target: _targets) {
        if (target->included() == false)
            continue;

        auto name = _prefix.rewrite(target->name());
        auto guard = "__pconfigure__deps-" + name;

        fprintf(file, "ifndef %s\n", guard.c_str());
        fprintf(file, "%s := 1\n", guard.c_str());
        fprintf(file, "include %s\n", name.c_str());
        fprintf(file, "endif\n\n");
    }

    auto stamp = check_stamp();
    for (const auto& target: _targets)
        target->write_to_file(file, _verbose, stamp, _prefix);

    if (_extra_deps.size() > 0) {
        fprintf(file, "# Dependencies implied by the command lines above.\n");
        for (const auto& dep: _extra_deps)
            fprintf(file, "%s: %s\n",
                    _prefix.rewrite(dep.first).c_str(),
                    _prefix.rewrite(dep.second).c_str());
        fprintf(file, "\n");
    }

    auto q = _verbose ? "" : "@";
    auto ptest = tool_command("ptest");
    auto pconfigure = tool_command("pconfigure");
    auto obj_dir = _prefix.rewrite(_obj_dir);
    auto quiet_report = obj_dir + "/check-report-quiet";
    auto report = obj_dir + "/check-report";

    /* The stamp is named after this project's object directory, so
     * every project has its own and a parent's waits on its
     * children's.
     *
     * It also waits on the file that says what it stands for (see
     * check_scopes()), and that is the half that isn't about time.
     * Every other prerequisite here is a test result, and a result is
     * older than the stamp whenever the test ran before the stamp
     * was last written -- which is true of a test that just moved into
     * the set as much as of one that was always there.  A failing test
     * moved into a suite, an INCLUDE_TEST_SUITES that pulls one in, a
     * subproject that was tested on its own before it was vendored:
     * each is a stamp whose prerequisites are all older than it, so
     * make called it current and "make check" said there was nothing
     * to do while "make report" over the same set, built fresh, listed
     * the failure.  Which results are in the set is something only the
     * Configfiles say, and this file is where that gets a timestamp.
     *
     * The empty rule is for a scope file that isn't there, which is a
     * tree somebody cleared out by hand: make takes a file with no
     * rule and no file as remade, so the stamp is too, and the next
     * report scores everything rather than stopping on "No rule to
     * make target". */
    auto all_scope = _prefix.rewrite(check_scope_path(""));
    fprintf(file, "%s:\n", all_scope.c_str());
    fprintf(file, "%s: %s\n", stamp.c_str(), all_scope.c_str());
    fprintf(file, "%s:", stamp.c_str());
    for (const auto& check_stamp: _check_stamps)
        fprintf(file, " %s", _prefix.rewrite(check_stamp).c_str());
    fprintf(file, "\n\t%smkdir -p %s\n\t%sdate > $@\n\n",
            q, obj_dir.c_str(), q);

    /* Everything from here down is a rule that every project would
     * write out under the same name, so only the project make was
     * actually run in gets to have them.  When a parent included this
     * one, the parent's copies are the ones that run, and they cover
     * this project too. */
    if (_prefix.included() == true)
        fprintf(file, "ifeq ($(%s),)\n\n", _prefix.variable().c_str());

    for (const auto& target: _standalone_targets)
        target->write_to_file(file, _verbose, stamp, _prefix);

    /* An ABRT_IS_FAIL Configfile line lands here, on every "make
     * check"/"make report" recipe that reads that project's results --
     * its own, the project-wide and the per-suite ones alike, and a
     * parent's that aggregate it -- rather than on ptest's own
     * default, which stays what it was for every project that didn't
     * ask.  It's said per directory rather than once for the whole
     * ptest run, since a parent's report covers projects that gave
     * different answers. */
    auto check_dirs = check_dirs_args();

    write_report_rule(file, quiet_report, stamp, q, ptest, true, check_dirs);
    write_report_rule(file, report, stamp, q, ptest, false, check_dirs);
    /* "make check" runs one named set of tests when the project said
     * which, and every test it has when it didn't.  "make report"
     * follows it: a report about a run that didn't happen is a report
     * of results left over from some earlier one. */
    auto check_quiet = quiet_report;
    auto check_report = report;
    if (_default_test_suite.size() > 0) {
        check_quiet = obj_dir + "/check-suite-" + _default_test_suite
                    + "-report-quiet";
        check_report = obj_dir + "/check-suite-" + _default_test_suite
                     + "-report";
    }

    /* Running pconfigure again, which is a thing to be asked for
     * rather than a thing that happens: what a Makefile says is what
     * the Configfiles said the last time somebody ran pconfigure, and
     * nothing in a build changes that on its own.
     *
     * The one that wrote this file, named by location, rather than
     * whatever $PATH has.  This used to be the bare name, on the
     * argument that reconfiguring is somebody deciding to reconfigure
     * and the pconfigure they mean is the one they have.  That argument
     * assumes they have one: a tree that vendors pconfigure and builds
     * it into src/pconfigure/bin has never installed it, so the bare
     * name names nothing and "make reconfigure" is a rule that cannot
     * run on a tree where every other rule works.  It is also the only
     * rule that was still asking -- pbashc, ptest, pdeps and the rest
     * have been resolved beside the running pconfigure for a while
     * (makefile::tool_command), so this one was inconsistent with its
     * own Makefile.
     *
     * What that costs: somebody who installs a newer pconfigure and
     * expects "make reconfigure" in an old tree to pick it up now has
     * to say so.  PCONFIGURE_ARGS is not the place for it, but running
     * the pconfigure they mean is, and that is what everyone who has
     * no installed copy at all had to do already.
     *
     * Run with the options that were given the last time, unless make
     * is given others.  This used to be nothing unless make was given
     * some, which made every rule below that runs pconfigure on its
     * own -- the Makefile's, under AUTORECONFIGURE, and the one that
     * puts back a subproject's deleted Makefile -- a run of a bare
     * pconfigure in a tree somebody had configured otherwise.  A
     * comment added to a Configfile was enough to take a --config's
     * targets out of the build, quieten a --verbose one, put a
     * --cross-compile one back on the host's compiler, and leave a
     * --srcpath build directory with a Makefile that built nothing,
     * none of which anybody had asked for.  "make reconfigure" gets
     * the same default for the same reason: a configure script that
     * forgets how it was run every time it runs is one somebody has
     * to remember for it.  "PCONFIGURE_ARGS=" with nothing after it
     * is how to ask for the bare run, and still works because "?="
     * gives way to anything make was told. */
    if (_write_reconfigure == true || _record_pconfigure_args == true)
        fprintf(file, "PCONFIGURE_ARGS ?=%s%s\n\n",
                _pconfigure_args.size() > 0 ? " " : "",
                _pconfigure_args.c_str());

    if (_write_reconfigure == true) {
        fprintf(file, ".PHONY: reconfigure\n");
        fprintf(file, "reconfigure:\n");
        fprintf(file, "\t%secho \"PCONFIGURE\"\n", q);
        fprintf(file, "\t%s%s $(PCONFIGURE_ARGS)\n\n", q, pconfigure.c_str());
    }

    /* What this Makefile was written out of, so that a Configfile
     * somebody edited is a Configfile the build reads again.  make
     * remakes the makefiles it was given before it reads them, which
     * is what makes this work at all.
     *
     * Every name goes through $(wildcard), and both halves of that
     * matter.  A name that is not there expands to nothing, which is
     * the only way to mention a Configfile.local that does not exist
     * -- naming it outright is a hard error, and giving it an empty
     * rule instead is the remake loop that never settles.  And
     * $(wildcard) is expanded afresh on every run, so the day such a
     * file is created it is a prerequisite newer than this Makefile.
     *
     * Except for a name this build has a rule for, where the second
     * half is the wrong way round.  A CONFIG_DEPS can name a file a
     * vendored tree installs -- the llvm-config a Configfile asks for
     * its flags -- and once that file exists $(wildcard) hands make
     * the bare name, make finds the rule, and builds the file before
     * it decides whether to reconfigure.  On a fresh tree the same
     * $(wildcard) expands to nothing, so make never learns the
     * configuration is waiting on it: the first make configures
     * against whatever the Configfile found instead, builds against
     * that, and only the make after the tool lands gets it right.
     * Written bare, the fresh tree builds the tool first like every
     * later one does.  A missing file is not a "No rule to make
     * target" for these, which is the only thing the $(wildcard) was
     * there to prevent.
     *
     * The names are whatever a CONFIG_DEPS said, so they are spelled
     * for where they land: a "cost$1.txt" handed to $(wildcard) as
     * written is looked for as "cost.txt", comes to nothing, and the
     * file is silently not watched at all.
     *
     * A project that keeps its committed Makefile beside this one
     * says the prerequisites here and leaves the recipe there, where
     * the pconfigure to run is named.  One target with its
     * prerequisites in two places is ordinary; two recipes would not
     * be. */
    if (_configfiles.size() > 0) {
        fprintf(file, "%s:", filename.c_str());
        for (const auto& configfile: _configfiles) {
            auto built = std::find(_configfiles_built.begin(),
                                   _configfiles_built.end(),
                                   configfile) != _configfiles_built.end();
            if (built)
                fprintf(file, " %s", prerequisite(configfile).c_str());
            else
                fprintf(file, " $(wildcard %s)",
                        function_argument(configfile).c_str());
        }
        fprintf(file, "\n");

        if (_write_reconfigure == true) {
            fprintf(file, "\t%secho \"PCONFIGURE\"\n", q);
            fprintf(file, "\t%s%s $(PCONFIGURE_ARGS)\n", q, pconfigure.c_str());
        }

        fprintf(file, "\n");
    }

    /* The files a configure wrote for the build to read -- the hash of
     * what goes into each link, the context pdeps works from, what a
     * vendored tree was configured with -- which rules name as
     * prerequisites and which nothing but a configure wrote.  They
     * live in object directories, and an object directory is a cache
     * that people delete; with one gone, every make after stopped on
     * "No rule to make target", in a tree whose Configfiles said
     * exactly what they said before.
     *
     * Each gets a rule that writes it again, saying what the
     * configure that wrote this Makefile put there -- which is the
     * answer a configure run now would give too, since this Makefile
     * is what that configure left and nothing has asked for another.
     * No prerequisites, so the rule means "if it is missing" and
     * nothing else: a file with no prerequisites is up to date for as
     * long as it exists.  And it comes back newer than whatever hangs
     * off it, which is the right answer for a link or a vendored
     * configure whose record of its inputs went away: doing it again
     * is the only way to know it is current.
     *
     * Rather than a rule that runs pconfigure, which was the other
     * way to put them back.  Without AUTORECONFIGURE a Makefile does
     * not rerun the configure that wrote it -- a Configfile somebody
     * edited is not picked up until they ask -- and a deleted object
     * directory is no reason for it to start; this way the build
     * after one is the build that was configured, and nothing more.
     * It is also one rule per file, so a make -j that finds several
     * gone writes each once rather than racing several configures
     * over all of them. */
    for (const auto& output: _configure_outputs) {
        fprintf(file, "%s:\n", output.first.c_str());
        fprintf(file, "\t%smkdir -p $(dir $@)\n", q);
        for (const auto& line: write_recipe(output.second))
            fprintf(file, "\t%s%s\n", q, line.c_str());
        fprintf(file, "\n");
    }

    fprintf(file, "check: %s\n\n", check_quiet.c_str());
    fprintf(file, "report: %s\n\t%scat %s\n\n",
            check_report.c_str(), q, check_report.c_str());

    /* A named set of tests is the same pair of rules over a smaller
     * pile of results: its own stamp, so that asking for it builds
     * only the tests in it, and its own reports, so that what comes
     * out is about the run that happened rather than about every
     * result that happens to be on disk. */
    for (const auto& suite: _test_suites) {
        /* "check-suite-" rather than "check-", because "check-all" is
         * the stamp every project has had all along and a suite is
         * allowed to be called "all" -- which would otherwise be two
         * rules for one file, and a "make check-all" that quietly ran
         * more than the suite it named. */
        auto suite_stamp = obj_dir + "/check-suite-" + suite.first + "-done";
        auto suite_quiet = obj_dir + "/check-suite-" + suite.first
                         + "-report-quiet";
        auto suite_report = obj_dir + "/check-suite-" + suite.first
                          + "-report";

        auto results = std::string(" --check-suite " + suite.first);
        for (const auto& result: suite.second)
            results += " --check-result " + _prefix.rewrite(result);

        /* The same scope file as the project-wide stamp has, for the
         * same reason: a suite is exactly the set a Configfile edit
         * can change without touching any result in it. */
        auto suite_scope = _prefix.rewrite(check_scope_path(suite.first));
        fprintf(file, "%s:\n", suite_scope.c_str());
        fprintf(file, "%s: %s\n", suite_stamp.c_str(), suite_scope.c_str());
        fprintf(file, "%s:", suite_stamp.c_str());
        for (const auto& result: suite.second)
            fprintf(file, " %s", _prefix.rewrite(result).c_str());
        fprintf(file, "\n\t%smkdir -p %s\n\t%sdate > $@\n\n",
                q, obj_dir.c_str(), q);

        /* The same pair of rules a suite at a time, out of the same
         * writer: see write_report_rule() for what that recipe is
         * shaped the way it is for. */
        write_report_rule(file, suite_quiet, suite_stamp, q, ptest, true,
                          check_dirs + results);
        write_report_rule(file, suite_report, suite_stamp, q, ptest, false,
                          check_dirs + results);

        /* Both of these are names rather than files, and unlike
         * "check" there is no directory that happens to be called
         * this -- so saying so is what keeps a stray file of the name
         * from stopping the rule, rather than what fixes anything
         * that has gone wrong. */
        fprintf(file, ".PHONY: check-%s\n", suite.first.c_str());
        fprintf(file, "check-%s: %s\n\n",
                suite.first.c_str(), suite_quiet.c_str());
        fprintf(file, ".PHONY: report-%s\n", suite.first.c_str());
        fprintf(file, "report-%s: %s\n\t%scat %s\n\n",
                suite.first.c_str(), suite_report.c_str(), q,
                suite_report.c_str());
    }

    if (_prefix.included() == true)
        fprintf(file, "endif\n\n");

    fclose(file);
}

std::vector<std::pair<std::string, std::string>>
makefile::makefile::check_scopes(void) const
{
    /* What a report reads is the ptest command line its rule runs,
     * and what the stamp waits on is its list of prerequisites, so
     * those are what a scope says.  A change to either is a change to
     * what "make check" is about; a change to neither -- a reconfigure
     * that comes out the same, a comment in a Configfile -- leaves the
     * file alone, and with it every result that is still current. */
    auto out = std::vector<std::pair<std::string, std::string>>();

    auto all = "ptest" + check_dirs_args() + "\n";
    for (const auto& dep: check_stamp_deps())
        all += dep + "\n";
    out.push_back(std::make_pair(check_scope_path(""), all));

    for (const auto& suite: _test_suites) {
        auto scope = "ptest" + check_dirs_args() + " --check-suite "
                   + suite.first + "\n";
        for (const auto& result: suite.second)
            scope += _prefix.rewrite(result) + "\n";
        out.push_back(std::make_pair(check_scope_path(suite.first), scope));
    }

    return out;
}

std::string makefile::makefile::check_scope_path(const std::string& suite) const
{
    /* "check-suite-" for the same reason as the suite's stamp: a suite
     * may be called "all". */
    if (suite.size() == 0)
        return _obj_dir + "/check-all-scope";
    return _obj_dir + "/check-suite-" + suite + "-scope";
}

std::string makefile::makefile::check_dirs_args(void) const
{
    auto out = std::string();
    for (const auto& dir: _check_dirs)
        out += (dir.second ? " --abrt-is-fail-dir " : " --check-dir ")
             + _prefix.rewrite(dir.first);
    return out;
}

std::vector<std::string> makefile::makefile::check_stamp_deps(void) const
{
    /* The same prerequisites target::write_to_file() and the stamp
     * rule hang off "check-all-done" between them, spelled the way
     * they come out in the Makefile. */
    auto out = std::vector<std::string>();
    for (const auto& list: {&_targets, &_standalone_targets})
        for (const auto& target: *list)
            if (target->has_global_target(global_targets::CHECK))
                out.push_back(_prefix.rewrite(target->name()));
    for (const auto& stamp: _check_stamps)
        out.push_back(_prefix.rewrite(stamp));
    return out;
}
