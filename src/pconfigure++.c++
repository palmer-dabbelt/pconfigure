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

#include <libpconfigure/commands.h++>
#include <libpconfigure/command_processor.h++>
#include <libpconfigure/project.h++>
#include "version.h"
#include <libmakefile/implied_deps.h++>
#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <map>
#include <set>
#include <vector>
#include <unistd.h>

/* Refuses a run that would read nothing at all.  Any one of the four
 * default Configfiles is allowed to be missing -- nobody has to write
 * a Configfile.local -- and so a file that isn't there is read as one
 * with no lines in it.  With all four missing, though, that turns into
 * an empty project: a Makefile holding nothing but the built-in rules,
 * an obj/ beside it and an exit status of 0, all written into whatever
 * directory pconfigure happened to be run from.  Running it one
 * directory too deep, in src/, is by far the likelier story than a
 * project that really is nothing, and it's the same mistake a
 * "--srcpath" naming a directory that isn't there is refused for.
 *
 * A run that was given something to read some other way is left
 * alone: a "--config" names a file of its own (and complains for
 * itself when that file isn't there), and a Configfile line written on
 * the command line is a project somebody described on purpose, even
 * if it's one with no Configfile behind it. */
static void check_something_to_read(const command_processor::ptr& processor,
                                    const std::vector<command::ptr>& given)
{
    for (const auto& command: given) {
        if (command->type() == command_type::CONFIG)
            return;

        /* The options are the words that start with a dash; anything
         * else on the command line was read as a Configfile line. */
        const auto& word = command->debug()->line();
        if (word.size() == 0 || word[0] != '-')
            return;
    }

    auto filenames = std::vector<std::string>{
        processor->srcpath() + "/Configfiles/local",
        processor->srcpath() + "/Configfile.local",
        processor->srcpath() + "/Configfiles/main",
        processor->srcpath() + "/Configfile"
    };

    /* Existence rather than readability, for the reason config_lines()
     * gives: a file that's there but can't be read is complained about,
     * with its reason, by the code that tries to read it. */
    for (const auto& filename: filenames)
        if (access(filename.c_str(), F_OK) == 0)
            return;

    std::cerr << "error: there is no Configfile to read: none of "
              << filenames[0] << ", " << filenames[1] << ", "
              << filenames[2] << " or " << filenames[3] << " exists\n"
              << "  pconfigure configures the project whose Configfiles"
              << " are in the directory it's run from, or the one"
              << " '--srcpath' names, and with none of them there it"
              << " would write a Makefile for an empty project\n"
              << "  run pconfigure from the project's top directory (the"
              << " one with Configfiles/main or Configfile in it), or name"
              << " that directory with '--srcpath'\n";
    abort();
}

int main(int argc, const char **argv)
{
    /* Every shell pconfigure starts while it configures -- the one
     * that runs an executable Configfile, the one that runs a
     * GENERATE script for its --deps, the one behind a backtick --
     * gets a "cd" somewhere in it, either pconfigure's own or the
     * script's, and nearly always to a relative path.  A relative cd
     * is the case CDPATH applies to.  Plenty of people export one
     * from their shell's rc file, and bash honours it in scripts as
     * well as at a prompt, so the cd looks its directory up along
     * CDPATH first: where an entry holds a directory of the same name
     * it goes there instead of the one meant, and wherever it used an
     * entry at all it prints the directory it arrived in on stdout.
     * stdout is exactly what pconfigure is reading, so that line
     * became the first line of a subproject's Configfile, or a
     * prerequisite of a generated file.
     *
     * Dropped here, once, rather than with a "CDPATH=" in front of
     * each cd, because the cds that matter are not all pconfigure's
     * to spell: a Configfile that is a program does its own.  Nothing
     * pconfigure runs has a use for it -- CDPATH is a convenience for
     * typing at a prompt, and autoconf's configure scripts unset it
     * first thing for the same reason.  The Makefiles keep it from
     * the recipes in the same way; see makefile::write_to_file(). */
    unsetenv("CDPATH");

    auto processor = std::make_shared<command_processor>();

    auto given = commands(argc, argv);
    for (const auto& command: given)
        processor->process(command);

    if (processor->given_help_command()) {
        std::cout <<
"usage: pconfigure [options]\n"
"\n"
"pconfigure reads a Configfile (by default Configfiles/main and Configfile in\n"
"the current directory) and generates a Makefile that builds the project.\n"
"\n"
"Options:\n"
"  -h, --help          Show this help message and exit\n"
"  --version           Show the pconfigure version and exit\n"
"  --verbose           Generate a Makefile that echoes each build command\n"
"  --debug             Print debugging information while generating the Makefile\n"
"  --config NAME       Also read Configfiles/NAME and Configfile.NAME\n"
"  --srcpath PATH      Treat PATH as the root of the source tree\n"
"  --phc PATH          Use PATH as the phc (header compiler) tool\n"
"  --cross-compile PREFIX\n"
"                      Build with the toolchain whose programs are named\n"
"                      PREFIXgcc and so on, e.g. aarch64-linux-gnu-; the same\n"
"                      as starting the first Configfile with CROSS_COMPILE\n"
"  --strict VERSION    Turn every warning that existed as of VERSION into an\n"
"                      error, e.g. --strict v0.13.  Defaults to v0.12, which\n"
"                      promotes nothing.\n"
"  --ppkg-config PATH  Use PATH as the ppkg-config tool\n"
"\n"
"See https://github.com/palmer-dabbelt/pconfigure for more information.\n";
        return 0;
    }

    if (processor->given_version_command()) {
        std::cout << "pconfigure " << PCONFIGURE_VERSION << std::endl;
        return 0;
    }

    /* The Configfiles are read after the command-line options have
     * been processed, because the command line can change where those
     * Configfiles live -- and because there's no point reading them
     * at all for --help or --version.  A "--srcpath" that isn't
     * there is asked about first, since it has a better thing to say
     * about why nothing would be read than "nothing would be read". */
    processor->check_srcpath();
    check_something_to_read(processor, given);

    auto seen = std::set<std::string>();
    auto top = project::read(processor, seen);
    auto projects = project::flatten(top);

    /* Dependencies are worked out with every project's targets in
     * hand: what one project wants can perfectly well be provided by
     * a project that was read after it. */
    auto targets = std::vector<makefile::target::ptr>();
    auto provided = std::vector<makefile::capability>();
    auto needed = std::vector<makefile::capability>();
    auto owner = std::map<std::string, std::string>();
    for (const auto& project: projects) {
        for (const auto& target: project->targets()) {
            /* Two projects that build the same path would be two
             * recipes for one target, and make would quietly pick
             * one.  The paths that can collide are the ones that
             * aren't rooted in a project -- where a file gets
             * installed to, most of all. */
            auto found = owner.find(target->name());
            if (found != owner.end() && found->second != project->base()) {
                std::cerr << "'" << target->name() << "' is built by both '"
                          << found->second << "' and '" << project->base()
                          << "'\n";
                abort();
            }
            owner[target->name()] = project->base();

            targets.push_back(target);
        }
        for (const auto& capability: project->provided())
            provided.push_back(capability);
        for (const auto& capability: project->needed())
            needed.push_back(capability);
    }

    project::check_prefix_variables(projects);

    auto implied = makefile::implied_deps(targets, provided, needed);

    /* A dependency goes in the Makefile of the deepest project that
     * includes both ends of it.  For a subproject that depends on
     * something the project above it built, that's the one above --
     * which is what keeps the subproject's own Makefile free of
     * targets it has no idea how to build, and so still usable on its
     * own. */
    auto reachable = std::map<std::string, std::set<std::string>>();
    for (const auto& project: projects)
        reachable[project->base()] = project->reachable();

    auto edges = std::map<std::string, std::vector<makefile::implied_dep>>();
    for (const auto& dep: implied) {
        auto target = owner.find(dep.target);
        auto needed = owner.find(dep.dep);
        if (target == owner.end() || needed == owner.end())
            continue;

        auto host = std::string();
        auto found = false;
        for (const auto& project: projects) {
            const auto& below = reachable[project->base()];
            if (below.find(target->second) == below.end())
                continue;
            if (below.find(needed->second) == below.end())
                continue;
            if (found == true && project->base().size() <= host.size())
                continue;

            host = project->base();
            found = true;
        }

        if (found == true)
            edges[host].push_back(dep);
    }

    for (const auto& project: projects)
        project->check_stale_makefile();

    /* Asked of the whole run rather than at the line, because the
     * tree a BOOTSTRAP names is read by the line that names it and
     * has no targets yet while that line is being processed. */
    for (const auto& project: projects)
        project->check_bootstrap(projects);

    /* Asked of the whole run for the same reason as the BOOTSTRAP
     * above: the LIBDIR that moves a directory distclean removes can
     * come after the SUBPROJECTS line that put a tree under it. */
    for (const auto& project: projects)
        project->check_distclean_spares_subprojects(
            project::flatten(project));

    /* Before a line of any Makefile is written, so that a build whose
     * "make check" would reach no test at all stops without leaving a
     * half-written set of them behind. */
    for (const auto& project: projects)
        project->check_default_test_suite(project::flatten(project));

    /* The same question asked per project rather than per suite, and
     * in the same place for the same reason.  Asked of every project
     * in the run and not only the one make gets run in, because a
     * project that is only ever included is a project somebody can
     * also walk into and type "make check" in -- and when they do,
     * the answer they get is the one this is about. */
    for (const auto& project: projects)
        project->check_aggregated_test_suites(project::flatten(project));

    /* Before any Makefile, rather than along with each project's own,
     * because the Makefile make is run on carries a rule for every
     * file like these that the run wrote (see
     * file_utils::write_configure_output()) -- and it is written
     * first, before a subproject's would have been. */
    for (const auto& project: projects)
        project->write_configureopts();

    for (const auto& project: projects)
        project->write_makefile(edges[project->base()],
                                project::flatten(project),
                                projects);

    return 0;
}
