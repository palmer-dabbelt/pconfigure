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
#include "../string_utils.h++"
#include <unistd.h>
#include <cctype>
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

kconfig_deps::roots build_system_kconfig::dep_roots(void) const
{
    /* A kbuild tree is rooted at a Makefile and a Kconfig, and some
     * trees use a Kbuild alongside the Makefile. */
    auto out = kconfig_deps::roots();
    out.config = {base() + "Kconfig"};
    out.build = {base() + "Makefile", base() + "Kbuild"};
    return out;
}

std::string build_system_kconfig::option_value(const std::string& opt,
                                               const std::string& flag)
{
    if (opt.compare(0, flag.size(), flag) != 0)
        return "";

    auto rest = opt.substr(flag.size());
    if (rest.size() == 0)
        return "";
    if (rest[0] != ' ' && rest[0] != '=')
        return "";

    return string_utils::clean_white(rest.substr(1));
}

bool build_system_kconfig::handle_configureopt(const std::string& opt)
{
    auto defconfig = option_value(opt, "--defconfig");
    if (defconfig.size() > 0) {
        _defconfig = defconfig;
        return true;
    }

    auto configure = option_value(opt, "--configure");
    if (configure.size() > 0) {
        auto equals = configure.find('=');
        if (equals == std::string::npos) {
            std::cerr << name() << ": '--configure " << configure
                      << "' has no value: it should look like"
                      << " '--configure CONFIG_FOO=y'\n";
            abort();
        }

        _options.push_back(option(configure.substr(0, equals),
                                  configure.substr(equals + 1)));
        return true;
    }

    return false;
}

std::string build_system_kconfig::configureopt_help(void) const
{
    return "  '--defconfig NAME' picks the target that writes the first"
           " configuration\n"
           "  '--configure OPTION=y' sets an option on top of it\n";
}

void build_system_kconfig::add_configureopt(const std::string& opt)
{
    if (handle_configureopt(opt) == true)
        return;

    std::cerr << name() << ": unknown CONFIGUREOPTS '" << opt << "'\n"
              << configureopt_help();
    abort();
}

std::vector<makefile::target::ptr> build_system_kconfig::targets(void) const
{
    auto srcdir = source_dir();
    auto output = kbuild_output();
    auto config = config_file();
    auto stamp = build_stamp();

    /* What make prints while it's configuring the tree.  It's the
     * name of the build system that's doing it, since that's the
     * thing whose options went into the .config. */
    auto label = name();
    for (auto& c: label)
        c = toupper(c);

    /* kbuild insists on being told where to put its output as an
     * absolute path, and pconfigure only ever works in relative ones
     * -- so make gets to do the conversion, at the point where it
     * knows what directory it's in. */
    auto submake = "$(MAKE) --no-print-directory -C " + srcdir
                 + " O=$(abspath " + output + ")" + submake_flags();

    auto deps = kconfig_deps::chase(base(), dep_roots());

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
        auto tool = config_tool();
        if (access(tool.c_str(), X_OK) != 0) {
            std::cerr << name() << ": '--configure' needs '" << tool << "',"
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
            else if (option.value.size() > 1
                     && option.value[0] == '"'
                     && option.value[option.value.size() - 1] == '"')
                /* A value that was written with quotes around it is a
                 * string, and a string symbol is the one kind whose
                 * value goes into the .config with quotes back on --
                 * which the tree's own program does and we don't.
                 * The quotes stay on here so that the shell takes
                 * them off, which is what keeps a string with a space
                 * in it one argument. */
                command += " --set-str " + option.name + " " + option.value;
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
        label + "\t" + srcdir,
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
