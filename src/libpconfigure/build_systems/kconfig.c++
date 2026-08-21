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
#include "../file_utils.h++"
#include "../string_utils.h++"
#include <sys/stat.h>
#include <unistd.h>
#include <cctype>
#include <iostream>

build_system_kconfig::build_system_kconfig(const std::string& name)
: build_system(name),
  _defconfig("defconfig"),
  _options(),
  _merges(),
  _make_vars(),
  _env(),
  _make_targets(),
  _depends(),
  _config_depends()
{
}

build_system* build_system_kconfig::clone(void) const
{
    /* Everything a CONFIGUREOPTS puts in here is a string or a vector
     * of them, so the copy constructor has already made the deep copy
     * this promises to make.  It stays that way as long as nobody
     * puts a pointer to something shared in the class. */
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

    auto merge = option_value(opt, "--merge-config");
    if (merge.size() > 0) {
        _merges.push_back(merge);
        return true;
    }

    auto make_var = option_value(opt, "--make-var");
    if (make_var.size() > 0) {
        if (make_var.find('=') == std::string::npos) {
            std::cerr << name() << ": '--make-var " << make_var
                      << "' has no value: it should look like"
                      << " '--make-var ARCH=arm64'\n";
            abort();
        }

        /* What was written is what make is told, character for
         * character.  Taking this apart here would mean putting it
         * back together later, and every way of doing that gets a
         * value with a space or a '$' in it wrong -- while a value
         * that reaches the Makefile untouched lets whoever wrote it
         * say "$(abspath x)" and mean it. */
        _make_vars.push_back(make_var);
        return true;
    }

    auto env = option_value(opt, "--env");
    if (env.size() > 0) {
        if (env.find('=') == std::string::npos) {
            std::cerr << name() << ": '--env " << env
                      << "' has no value: it should look like"
                      << " '--env PATH=/opt/gnubin:$(PATH)'\n";
            abort();
        }

        _env.push_back(env);
        return true;
    }

    auto make_target = option_value(opt, "--target");
    if (make_target.size() > 0) {
        _make_targets.push_back(make_target);
        return true;
    }

    /* The longer flag is looked for first so that none of this rests
     * on "--depend" refusing to match "--depend-config".  It does
     * refuse, but only because option_value() insists the character
     * after a flag be a space or an '=', which is a thing to know
     * rather than a thing to lean on. */
    auto config_depend = option_value(opt, "--depend-config");
    if (config_depend.size() > 0) {
        _config_depends.push_back(config_depend);
        return true;
    }

    auto depend = option_value(opt, "--depend");
    if (depend.size() > 0) {
        _depends.push_back(depend);
        return true;
    }

    return false;
}

std::string build_system_kconfig::make_var_flags(void) const
{
    auto out = std::string();

    /* A kbuild tree already knows what CROSS_COMPILE means -- it's
     * where the rest of the world got the spelling from -- so a
     * project that said which machine it's building for has said this
     * too, and making somebody say it a second time is just a way of
     * letting the two answers disagree.  Whoever wrote the
     * CONFIGUREOPTS still gets to disagree on purpose: a vendored
     * tree that has to be built with a different toolchain than the
     * project around it is a thing that happens, and saying so is
     * what a --make-var is for. */
    if (wants_cross_compile() == true && ctx()->cross_compile.size() > 0) {
        auto flag = std::string("CROSS_COMPILE=");

        auto given = false;
        for (const auto& make_var: _make_vars)
            if (make_var.compare(0, flag.size(), flag) == 0)
                given = true;

        if (given == false)
            out += " " + flag + ctx()->cross_compile;
    }

    for (const auto& make_var: _make_vars)
        out += " " + make_var;

    return out;
}

std::string build_system_kconfig::with_env(const std::string& command) const
{
    auto out = std::string();
    for (const auto& env: _env)
        out += env + " ";

    return out + command;
}

std::string build_system_kconfig::based_file(const std::string& flag,
                                             const std::string& path) const
{
    auto out = file_utils::normalize_path(ctx()->base + path);

    /* A prerequisite is written into the Makefile of the project that
     * asked for it, and that Makefile has to keep working when
     * somebody runs make in that project rather than above it.  Only
     * a path that stays inside the project can be rewritten to say
     * both of those things at once, so one that climbs out is a
     * question with two answers rather than a path. */
    if (out.compare(0, 3, "../") == 0) {
        std::cerr << name() << ": '" << flag << " " << path << "' can't reach"
                  << " outside the project\n";
        abort();
    }

    struct stat buf;
    if (stat(out.c_str(), &buf) != 0 || S_ISREG(buf.st_mode) == false) {
        std::cerr << name() << ": '" << flag << " " << path << "' names '"
                  << out << "', which isn't a file\n";
        abort();
    }

    return out;
}

std::string build_system_kconfig::resolve_depend(
    const std::string& flag,
    const std::string& path,
    const std::vector<build_system::ptr>& peers) const
{
    /* A subproject is spelled here the same way it was spelled in the
     * SUBPROJECTS that pulled it in, so the same function has to tidy
     * it up: two spellings of one directory that don't come out of
     * here identical are two different directories as far as the
     * search below can tell. */
    auto dir = file_utils::normalize_directory(ctx()->base + path);
    auto file = file_utils::normalize_path(ctx()->base + path);

    if (dir == base()) {
        std::cerr << name() << ": '" << flag << " " << path << "' names this"
                  << " subproject\n";
        abort();
    }

    /* Everything a Makefile this run writes names is named relative
     * to where pconfigure ran, so a path that climbs out of that tree
     * is one no Makefile here owns. */
    if (dir.compare(0, 3, "../") == 0) {
        std::cerr << name() << ": '" << flag << " " << path << "' can't reach"
                  << " outside the project\n";
        abort();
    }

    /* Peers are the trees this same project vendored, and only those:
     * targets are generated at the end of every project, so a tree
     * some other project pulled in was never in this list and falls
     * through to the error at the bottom.  Within one project the
     * order doesn't matter, since every SUBPROJECTS has been read
     * before any of this runs. */
    for (const auto& peer: peers)
        if (peer->base() == dir && peer->build_stamp().size() > 0)
            return peer->build_stamp();

    struct stat buf;
    if (stat(file.c_str(), &buf) == 0 && S_ISREG(buf.st_mode) == true)
        return file;

    /* A pconfigure subproject is never a peer -- it's read into this
     * run rather than built by one -- so it always lands here, which
     * is where a typo lands too and both want the same advice. */
    if (stat(dir.c_str(), &buf) == 0 && S_ISDIR(buf.st_mode) == true) {
        std::cerr << name() << ": '" << flag << " " << path << "' names '"
                  << dir << "', which isn't a vendored subproject\n"
                  << "  a pconfigure subproject has no one file that says"
                  << " it's been built,\n"
                  << "  so name the file you actually need instead\n";
        abort();
    }

    std::cerr << name() << ": '" << flag << " " << path << "' names '"
              << file << "', which is neither a file nor a vendored"
              << " subproject\n";
    abort();
}

std::string build_system_kconfig::configureopt_help(void) const
{
    return "  '--defconfig NAME' picks the target that writes the first"
           " configuration\n"
           "  '--configure OPTION=y' sets an option on top of it\n"
           "  '--merge-config FILE' merges a configuration fragment into"
           " it\n"
           "  '--make-var NAME=VALUE' puts a variable on the sub-make's"
           " command line\n"
           "  '--env NAME=VALUE' puts a variable in the environment it runs"
           " in\n"
           "  '--target NAME' asks the tree for a target rather than for its"
           " default\n"
           "  '--depend PATH' waits for something else before building\n"
           "  '--depend-config PATH' waits for something else before"
           " configuring\n";
}

void build_system_kconfig::add_configureopt(const std::string& opt)
{
    if (handle_configureopt(opt) == true)
        return;

    std::cerr << name() << ": unknown CONFIGUREOPTS '" << opt << "'\n"
              << configureopt_help();
    abort();
}

std::vector<makefile::target::ptr>
build_system_kconfig::targets(const std::vector<build_system::ptr>& peers) const
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
     * knows what directory it's in.
     *
     * Everything a CONFIGUREOPTS said about how the tree gets run is
     * built into this one string rather than into the places it's
     * used, because the defconfig, the olddefconfig and the build all
     * have to be told the same thing.  A tree handed "ARCH=arm64" for
     * two of the three writes a .config for one machine and then
     * builds for another. */
    auto submake = with_env("$(MAKE) --no-print-directory -C " + srcdir
                          + " O=$(abspath " + output + ")"
                          + submake_flags() + make_var_flags());

    auto deps = kconfig_deps::chase(base(), dep_roots());

    /********************************************************************
     * The configuration                                                *
     ********************************************************************/
    auto config_deps = std::vector<makefile::target::ptr>();
    for (const auto& path: deps.config)
        config_deps.push_back(std::make_shared<makefile::target>(path));
    for (const auto& path: kconfig_deps::defconfig_files(base(), _defconfig))
        config_deps.push_back(std::make_shared<makefile::target>(path));
    for (const auto& depend: _config_depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend-config", depend, peers)));

    auto config_commands = std::vector<std::string>{
        "mkdir -p " + output,
        submake + " " + _defconfig,
    };

    if (_merges.size() > 0) {
        auto tool = merge_config_tool();
        if (access(tool.c_str(), X_OK) != 0) {
            std::cerr << name() << ": '--merge-config' needs '" << tool << "',"
                      << " which this tree doesn't have\n";
            abort();
        }

        /* Where the merged configuration lands is said once, in the
         * environment.  The other way to say it is "-O", which sends
         * the path through a readlink that only GNU coreutils has and
         * refuses a directory that doesn't exist yet, and which says
         * a second thing about where the output goes on top of the
         * thing it was asked to say.  "-m" is what keeps the program
         * from running the tree's own make from a directory that
         * isn't the tree, which is what the olddefconfig below is
         * for. */
        auto command = with_env("KCONFIG_CONFIG=" + config
                              + " " + tool + " -m " + config);

        /* The fragments go on in the order they were written, since
         * that's the order the program reads them in and a later one
         * is allowed to overwrite an earlier one. */
        for (const auto& merge: _merges) {
            auto path = based_file("--merge-config", merge);
            command += " " + path;
            config_deps.push_back(std::make_shared<makefile::target>(path));
        }

        config_commands.push_back(command);
        config_deps.push_back(std::make_shared<makefile::target>(tool));
    }

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
            auto command = with_env(tool + " --file " + config);

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

        config_deps.push_back(std::make_shared<makefile::target>(tool));
    }

    /* Whatever a fragment or an option turned on has dependencies of
     * its own, and this is what fills them in.  It's the same job
     * either way, which is why it's here rather than in each of the
     * two blocks above: a .config that somebody wrote into is a
     * .config Kconfig hasn't had the last word on yet. */
    if (_merges.size() > 0 || _options.size() > 0)
        config_commands.push_back(submake + " olddefconfig");

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
    for (const auto& depend: _depends)
        build_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    /* One sub-make per target rather than one sub-make with a list of
     * goals, in the order the targets were asked for.  A "make -j"
     * handed several goals is allowed to run them at the same time,
     * and neither kbuild nor anything that copied it is safe against
     * that at the top of the tree.  The stamp still gets written
     * last, so it says every target that was asked for succeeded --
     * which is all it can say, since it can't say which targets those
     * were: re-running pconfigure rewrites this recipe, but nothing
     * about a rule's recipe changing is a reason for make to run it,
     * so a tree that's already built stays built. */
    auto build_commands = std::vector<std::string>();
    if (_make_targets.size() == 0)
        build_commands.push_back(submake);
    for (const auto& make_target: _make_targets)
        build_commands.push_back(submake + " " + make_target);
    build_commands.push_back("mkdir -p " + output_dir());
    build_commands.push_back("date > $@");

    auto build_target = std::make_shared<makefile::target>(
        stamp,
        "MAKE\t" + srcdir,
        build_deps,
        std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        },
        build_commands,
        std::vector<std::string>{
            "The vendored build system in " + srcdir + ", which is run"
            " whenever one of the files it could read has changed"
        }
    );

    return std::vector<makefile::target::ptr>{config_target, build_target};
}
