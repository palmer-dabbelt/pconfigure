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
#include <vector>

int main(int argc, const char **argv)
{
    auto processor = std::make_shared<command_processor>();

    for (const auto& command: commands(argc, argv))
        processor->process(command);

    /* The Configfiles are read after the command-line options have
     * been processed because the command line can change where those
     * Configfiles live. */
    if (processor->given_help_command() == false
        && processor->given_version_command() == false)
        for (const auto& command: configfiles(processor->srcpath()))
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
"  --ppkg-config PATH  Use PATH as the ppkg-config tool\n"
"\n"
"See https://github.com/palmer-dabbelt/pconfigure for more information.\n";
        return 0;
    }

    if (processor->given_version_command()) {
        std::cout << "pconfigure " << PCONFIGURE_VERSION << std::endl;
        return 0;
    }

    auto projects = std::vector<project::ptr>{
        std::make_shared<project>(processor->base(), processor)
    };

    for (const auto& project: projects)
        project->generate_targets();

    /* Dependencies are worked out with every project's targets in
     * hand: what one project wants can perfectly well be provided by
     * a project that was read after it. */
    auto targets = std::vector<makefile::target::ptr>();
    auto provided = std::vector<makefile::capability>();
    auto needed = std::vector<makefile::capability>();
    for (const auto& project: projects) {
        for (const auto& target: project->targets())
            targets.push_back(target);
        for (const auto& capability: project->provided())
            provided.push_back(capability);
        for (const auto& capability: project->needed())
            needed.push_back(capability);
    }

    auto implied = makefile::implied_deps(targets, provided, needed);

    for (const auto& project: projects)
        project->write_makefile(implied);

    return 0;
}
