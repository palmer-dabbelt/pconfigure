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
#include <iostream>

makefile::makefile::makefile(bool verbose,
                             const std::string& obj_dir,
                             const path_prefix& prefix)
: _verbose(verbose),
  _obj_dir(obj_dir),
  _prefix(prefix)
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
                                        const std::string& base)
{
    _subprojects.push_back(std::make_pair(variable, base));
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

void makefile::makefile::add_check_dir(const std::string& dir)
{
    _check_dirs.push_back(dir);
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

void makefile::makefile::write_to_file(const std::string& filename)
{
    auto file = fopen(filename.c_str(), "w");
    if (file == NULL) {
        std::cerr << "Unable to open " << filename << "\n";
        abort();
    }

    fprintf(file, "SHELL=/bin/bash\n\n");

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
                subproject.first.c_str(),
                _prefix.rewrite(subproject.second).c_str());
    if (_peers.size() > 0 || _subprojects.size() > 0)
        fprintf(file, "\n");

    /* The subprojects come after "all" so that it stays the rule make
     * picks when it isn't told what to build, and before everything
     * else so that a subproject's rules are in hand by the time
     * anything here refers to them. */
    for (const auto& subproject: _subprojects)
        fprintf(file, "include $(%s)Makefile\n\n", subproject.first.c_str());

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
    auto obj_dir = _prefix.rewrite(_obj_dir);
    auto quiet_report = obj_dir + "/check-report-quiet";
    auto report = obj_dir + "/check-report";

    /* The stamp is named after this project's object directory, so
     * every project has its own and a parent's waits on its
     * children's. */
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

    auto check_dirs = std::string();
    for (const auto& dir: _check_dirs)
        check_dirs += " --check-dir " + _prefix.rewrite(dir);

    fprintf(file, "%s: %s\n\t%s%s --quiet --no-check-make-check%s > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n",
            quiet_report.c_str(), stamp.c_str(), q, ptest.c_str(), check_dirs.c_str());
    fprintf(file, "%s: %s\n\t%s%s --no-check-make-check%s > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n",
            report.c_str(), stamp.c_str(), q, ptest.c_str(), check_dirs.c_str());
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

        fprintf(file, "%s:", suite_stamp.c_str());
        for (const auto& result: suite.second)
            fprintf(file, " %s", _prefix.rewrite(result).c_str());
        fprintf(file, "\n\t%smkdir -p %s\n\t%sdate > $@\n\n",
                q, obj_dir.c_str(), q);

        fprintf(file, "%s: %s\n\t%s%s --quiet --no-check-make-check%s%s > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n",
                suite_quiet.c_str(), suite_stamp.c_str(), q, ptest.c_str(),
                check_dirs.c_str(), results.c_str());
        fprintf(file, "%s: %s\n\t%s%s --no-check-make-check%s%s > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n",
                suite_report.c_str(), suite_stamp.c_str(), q, ptest.c_str(),
                check_dirs.c_str(), results.c_str());

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
