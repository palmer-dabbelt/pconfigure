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

#include "kconfig.h++"
#include "kconfig_deps.h++"
#include "../string_utils.h++"
#include <unistd.h>
#include <iostream>

build_system_kconfig::build_system_kconfig(const std::string& name)
: build_system(name),
  _defconfig("defconfig"),
  _options()
{
}

build_system* build_system_kconfig::clone(void) const
{
    return new build_system_kconfig(*this);
}

bool build_system_kconfig::can_build(const std::string& base) const
{
    /* A Kconfig is what makes this a kbuild tree rather than some
     * other tree with a Makefile in it, and something for make to
     * read is what makes it buildable at all. */
    if (access((base + "Kconfig").c_str(), R_OK) != 0)
        return false;

    return access((base + "Makefile").c_str(), R_OK) == 0
        || access((base + "Kbuild").c_str(), R_OK) == 0;
}

void build_system_kconfig::add_configureopt(const std::string& opt)
{
    /* An option is written either as two words or as one with an '='
     * in the middle, since both spellings turn up in the wild and
     * neither is any harder to read than the other. */
    auto split = [&](const std::string& flag) -> std::string {
        if (opt.compare(0, flag.size(), flag) != 0)
            return "";

        auto rest = opt.substr(flag.size());
        if (rest.size() == 0)
            return "";
        if (rest[0] != ' ' && rest[0] != '=')
            return "";

        return string_utils::clean_white(rest.substr(1));
    };

    auto defconfig = split("--defconfig");
    if (defconfig.size() > 0) {
        _defconfig = defconfig;
        return;
    }

    auto configure = split("--configure");
    if (configure.size() > 0) {
        auto equals = configure.find('=');
        if (equals == std::string::npos) {
            std::cerr << "kconfig: '--configure " << configure
                      << "' has no value: it should look like"
                      << " '--configure CONFIG_FOO=y'\n";
            abort();
        }

        _options.push_back(option(configure.substr(0, equals),
                                  configure.substr(equals + 1)));
        return;
    }

    std::cerr << "kconfig: unknown CONFIGUREOPTS '" << opt << "'\n"
              << "  the kconfig build system understands"
              << " '--defconfig NAME' and '--configure OPTION=y'\n";
    abort();
}

std::vector<makefile::target::ptr> build_system_kconfig::targets(void) const
{
    auto srcdir = source_dir();
    auto output = kbuild_output();
    auto config = config_file();
    auto stamp = build_stamp();

    /* kbuild insists on being told where to put its output as an
     * absolute path, and pconfigure only ever works in relative ones
     * -- so make gets to do the conversion, at the point where it
     * knows what directory it's in. */
    auto submake = "$(MAKE) --no-print-directory -C " + srcdir
                 + " O=$(abspath " + output + ")";

    auto deps = kconfig_deps::chase(base());

    /********************************************************************
     * The configuration                                                *
     ********************************************************************/
    auto config_deps = std::vector<makefile::target::ptr>();
    for (const auto& path: deps.config)
        config_deps.push_back(std::make_shared<makefile::target>(path));
    for (const auto& path: kconfig_deps::defconfig_files(base(), _defconfig))
        config_deps.push_back(std::make_shared<makefile::target>(path));

    auto config_commands = std::vector<std::string>{
        "mkdir -p " + output,
        submake + " " + _defconfig,
    };

    if (_options.size() > 0) {
        /* Setting an option after the fact is the vendored tree's job
         * rather than ours: a .config isn't a list of settings, it's
         * the answer Kconfig worked out, and editing it by hand gets
         * something subtly wrong every time. */
        auto tool = base() + "scripts/config";
        if (access(tool.c_str(), X_OK) != 0) {
            std::cerr << "kconfig: '--configure' needs '" << tool << "',"
                      << " which this tree doesn't have\n";
            abort();
        }

        for (const auto& option: _options) {
            auto command = tool + " --file " + config;

            if (option.value == "y")
                command += " --enable " + option.name;
            else if (option.value == "m")
                command += " --module " + option.name;
            else if (option.value == "n")
                command += " --disable " + option.name;
            else
                command += " --set-val " + option.name + " " + option.value;

            config_commands.push_back(command);
        }

        /* Whatever those options turned on has dependencies of its
         * own, and this is what fills them in. */
        config_commands.push_back(submake + " olddefconfig");

        config_deps.push_back(std::make_shared<makefile::target>(tool));
    }

    /* A defconfig that changed nothing leaves the file exactly as it
     * was, mtime included, which would leave it older than whatever
     * asked for it and run this again on every make. */
    config_commands.push_back("touch $@");

    auto config_target = std::make_shared<makefile::target>(
        config,
        "KCONFIG\t" + srcdir,
        config_deps,
        std::vector<makefile::global_targets>{},
        config_commands,
        std::vector<std::string>{
            "The configuration of the vendored build system in " + srcdir
        }
    );

    /********************************************************************
     * The build                                                        *
     ********************************************************************/
    /* Everything the vendored tree could read hangs off this one
     * stamp.  None of it says what gets built out of what -- that's
     * the sub-make's business, and it's better at it than any guess
     * made out here would be.  All these are for is giving make a
     * reason not to recurse at all. */
    auto build_deps = std::vector<makefile::target::ptr>{config_target};
    for (const auto& path: deps.build)
        build_deps.push_back(std::make_shared<makefile::target>(path));

    auto build_target = std::make_shared<makefile::target>(
        stamp,
        "MAKE\t" + srcdir,
        build_deps,
        std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        },
        std::vector<std::string>{
            submake,
            "mkdir -p " + output_dir(),
            "date > $@",
        },
        std::vector<std::string>{
            "The vendored build system in " + srcdir + ", which is run"
            " whenever one of the files it could read has changed"
        }
    );

    return std::vector<makefile::target::ptr>{config_target, build_target};
}
