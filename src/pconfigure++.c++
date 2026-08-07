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
#include <libpconfigure/pick_language.h++>
#include "version.h"
#include <libmakefile/makefile.h++>
#include <algorithm>
#include <iostream>
#include <map>

int main(int argc, const char **argv)
{
    auto processor = std::make_shared<command_processor>();
    auto targets = std::map<std::string, makefile::target::ptr>();

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
"  --ppkg-config PATH  Use PATH as the ppkg-config tool\n"
"\n"
"See https://github.com/palmer-dabbelt/pconfigure for more information.\n";
        return 0;
    }

    if (processor->given_version_command()) {
        std::cout << "pconfigure " << PCONFIGURE_VERSION << std::endl;
        return 0;
    }

    /* FIXME: If any target is verbose, then all are. */
    bool verbose = [&](void) -> bool {
        for (const auto& context: processor->output_contexts())
            if (context->verbose == true)
                return true;

        return false;
        }();

    auto makefile = std::make_shared<makefile::makefile>(verbose);

    auto distcleaned = std::map<std::string, bool>();
    auto obj_dirs = std::map<std::string, bool>();
    for (const auto& context: processor->output_contexts()) {
        if (context->debug == true)
            std::cerr << "Building Context: " << context->cmd->data() << "\n";

        auto language = pick_language(context->languages, context);
        for (const auto& target: language->targets(context)) {
            if (targets.find(target->name()) == targets.end()) {
                if (context->debug == true)
                    std::cerr << "  target: " << target->name() << "\n";
                makefile->add_target(target);
            } else if (!same_recipe(targets.find(target->name())->second, target)) {
                std::cout << "Mismatched recipe for targets with same name\n";
                abort();
            }
            targets[target->name()] = target;
        }

        auto to_distclean = std::vector<std::string>{
            context->bin_dir,
            context->check_dir,
            context->lib_dir,
            context->obj_dir
        };
        for (const auto& dir: to_distclean)
            distcleaned[dir] = true;

        obj_dirs[context->obj_dir] = true;
    }

    {
        auto dirs = std::vector<std::string>();
        for (const auto& pair: obj_dirs)
            dirs.push_back(pair.first);

        auto cache_clean_commands = std::vector<std::string>();
        for (const auto& dir: dirs) {
            cache_clean_commands.push_back(
                "comm -23 "
                "<(find " + dir + " -type f | sort) "
                "<(sed -n 's/\\(^" + dir + "\\/[^[:space:]:]*\\):.*/\\1/p' Makefile | sort -u) "
                "| xargs -r rm -f"
            );
            cache_clean_commands.push_back("find " + dir + " -type d -empty -delete");
        }

        auto target = std::make_shared<makefile::target>(
            "cache-clean",
            "CACHE-CLEAN",
            std::vector<makefile::target::ptr>{},
            std::vector<makefile::global_targets>{},
            cache_clean_commands,
            std::vector<std::string>{"cache-clean"}
        );

        makefile->add_target(target);
    }

    {
        auto distclean_commands = std::vector<std::string>();
        for (const auto& pair: distcleaned)
            distclean_commands.push_back("rm -rf " + pair.first);
        distclean_commands.push_back("rm -rf Makefile");

        auto target = std::make_shared<makefile::target>(
            "distclean",
            "DISTCLEAN",
            std::vector<makefile::target::ptr>{},
            std::vector<makefile::global_targets>{},
            distclean_commands,
            std::vector<std::string>{"distclean"}
        );

        makefile->add_target(target);
    }

    makefile->write_to_file("Makefile");
    
    return 0;
}
