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
#include <iostream>
#include <map>
#include <set>
#include <vector>

int main(int argc, const char **argv)
{
    auto processor = std::make_shared<command_processor>();

    for (const auto& command: commands(argc, argv))
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
     * at all for --help or --version. */
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

    /* Two projects whose directories mangle to the same variable
     * would each think the variable was theirs, and one of them would
     * end up building into the other's directory. */
    auto variables = std::map<std::string, std::string>();
    for (const auto& project: projects) {
        auto variable = project::prefix_variable(project->base());
        auto found = variables.find(variable);
        if (found != variables.end()) {
            std::cerr << "'" << found->second << "' and '" << project->base()
                      << "' both want the make variable '" << variable
                      << "'\n";
            abort();
        }
        variables[variable] = project->base();
    }

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
        project->write_makefile(edges[project->base()],
                                project::flatten(project));

    return 0;
}
