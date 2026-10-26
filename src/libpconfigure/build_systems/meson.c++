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

#include "meson.h++"
#include "vendored.h++"
#include "../file_utils.h++"
#include "../string_utils.h++"
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <iostream>

build_system_meson::build_system_meson(const std::string& name)
: build_system(name),
  _build_type(),
  _defines(),
  _configure_args(),
  _setup_script(),
  _prefix(),
  _install(true),
  _ninja_targets(),
  _jobs(),
  _env(),
  _depends(),
  _config_depends(),
  _configure_lines(),
  _build_lines()
{
}

build_system* build_system_meson::clone(void) const
{
    /* Strings, a bool and vectors of strings, so the copy constructor
     * is already the deep copy this promises. */
    return new build_system_meson(*this);
}

bool build_system_meson::can_build(const std::string& base) const
{
    /* A meson.build at the top is what "meson setup" looks for, so
     * it's what this looks for.  A tree that also ships some other
     * build system's files is not refused here: which of two real
     * answers was meant is the BUILD_SYSTEMS order's to say. */
    return access((base + "meson.build").c_str(), R_OK) == 0;
}

std::string build_system_meson::with_env(const std::string& command) const
{
    auto out = std::string();

    /* The value quoted and the name not, so that the shell still reads
     * an assignment in front of a command: see
     * build_system_cmake::with_env(), which is the same line. */
    for (const auto& env: _env) {
        auto equals = env.find('=');
        out += env.substr(0, equals + 1)
             + string_utils::quoted(env.substr(equals + 1))
             + " ";
    }

    return out + command;
}

std::string build_system_meson::install_prefix(void) const
{
    if (private_prefix() == true)
        return output_dir() + "/prefix";

    return checked_install_dir("--prefix", _prefix);
}

std::string build_system_meson::install_dir(void) const
{
    if (_install == false)
        return "";

    return install_prefix();
}

std::string build_system_meson::build_dir(void) const
{
    return _install == true ? install_prefix() : meson_build_dir();
}

std::string build_system_meson::build_command(const std::string& target) const
{
    /* The target is quoted and the build directory isn't, which is the
     * same split cmake makes and for the same reasons: one --target is
     * one target however many spaces are in it, and a path in a recipe
     * is a bare word all over pconfigure -- see
     * build_system_cmake::build_command() for why quoting this one
     * wouldn't buy what it looks like it buys. */
    auto out = "ninja -C " + meson_build_dir();

    /* Digits or it never got past take_configureopt(). */
    if (_jobs.size() > 0)
        out += " -j " + _jobs;

    if (target.size() > 0)
        out += " " + string_utils::quoted(target);

    return with_env(out);
}

std::string build_system_meson::configureopt_help(void) const
{
    return "  '--build-type NAME' sets meson's buildtype\n"
           "  '--define NAME=VALUE' sets a build option\n"
           "  '--prefix DIR' says where the tree installs to\n"
           "  '--configure-arg ARG' puts one more argument on the setup's"
           " command line\n"
           "  '--setup-script PATH' runs the tree's own script in place of"
           " 'meson setup'\n"
           "  '--target NAME' asks ninja for a target rather than for"
           " its default\n"
           "  '--jobs N' says how many jobs ninja may use\n"
           "  '--install' and '--no-install' say whether building the tree"
           " installs it\n"
           "  '--env NAME=VALUE' puts a variable in the environment it runs"
           " in\n"
           "  '--depend PATH' waits for something else before configuring"
           " and building\n"
           "  '--depend-config PATH' waits for something else before"
           " configuring\n";
}

build_system::answers build_system_meson::already_answered(void) const
{
    auto out = answers();

    /* meson reads a builtin option three ways: as "--NAME=VALUE" or
     * "--NAME VALUE" on its own command line, as "-DNAME=VALUE", and
     * as the bare "NAME=VALUE" a --define writes before the "-D" goes
     * on the front. */
    out.decorations = std::vector<std::string>{"", "-D", "--"};

    /* meson's command line is Python's argparse, which takes any
     * unambiguous prefix of a long option as the option: confirmed
     * against meson 1.12, where "--prefi=/x" sets the prefix and only
     * "--pre", which could also be "--prefer-static", is refused.  So
     * "--prefix" refused and "--prefi" accepted would be the same line
     * with a character taken off it. */
    out.abbreviated = true;

    /* No name below has an '_' in it for a '-' to stand for. */
    out.dashed = false;

    out.prefix_option = "--prefix DIR";

    /* meson joins a relative directory option to the prefix -- that
     * is what every one of them means when it is relative -- so
     * '--define libdir=lib' cannot name anything outside the prefix
     * and there is no reason to refuse it. */
    out.relative_subdirectories = true;

    /* Where the whole install goes.  "prefix" is meson's.  DESTDIR is
     * read out of the environment by the install, and pasted onto the
     * front of every path it writes, so it is the one of these an
     * --env can say.  "destdir" is "meson install"'s own spelling of
     * the same thing: nothing here passes a word to "meson install",
     * but a word that would mean that if it got there means it in any
     * spelling, and a refusal that depended on where the word landed
     * would be a refusal nobody could predict. */
    out.destinations.push_back({"prefix", "says where the tree installs to"});
    out.destinations.push_back({"DESTDIR", "says where the tree installs to"});
    out.destinations.push_back(
        {"destdir",
         "says where the tree installs to, being meson's own spelling of"
         " DESTDIR"});

    /* And where one kind of file goes inside the prefix: meson's
     * directory options, every one of which is read under the prefix
     * when it's relative and out from under it when it isn't. */
    for (const auto& option: {
            "bindir", "datadir", "includedir", "infodir", "libdir",
            "licensedir", "libexecdir", "localedir", "localstatedir",
            "mandir", "sbindir", "sharedstatedir", "sysconfdir"})
        out.subdirectories.push_back(
            {option, "says where part of the install goes"});

    /* No directories.  "meson setup" takes the build and source
     * directories as two positional arguments rather than as options,
     * so there is no name for a second answer to arrive under -- and a
     * third positional argument is not a second answer at all but an
     * error, which meson reports itself. */

    return out;
}

void build_system_meson::take_configureopt(const std::string& opt)
{
    auto whole = string_utils::clean_white(opt);

    auto build_type = option_value(opt, "--build-type");
    if (build_type.size() > 0) {
        _build_type = build_type;
        _configure_lines.push_back(opt);
        return;
    }

    auto define = option_value(opt, "--define");
    if (define.size() > 0) {
        if (define.find('=') == std::string::npos) {
            std::cerr << name() << ": '--define " << define
                      << "' has no value: it should look like"
                      << " '--define tests=false'\n";
            abort();
        }

        /* meson stops on a "-D" whose name is empty ("must be in
         * OPTION=VALUE format") when the tree is set up.  Only that is
         * refused: an option's name can carry a subproject's name and
         * a ':' in front of it, or a language and a '.', and which of
         * those this tree has is meson's to say. */
        refuse_unnamed("--define", define,
                       string_utils::clean_white(
                           define.substr(0, define.find('='))),
                       "tests=false");

        refuse_second_answer("--define", define);

        _defines.push_back(define);
        _configure_lines.push_back(opt);
        return;
    }

    auto prefix = option_value(opt, "--prefix");
    if (prefix.size() > 0) {
        /* Asked about by install_prefix(), once there is a project to
         * resolve it against. */
        _prefix = prefix;
        _configure_lines.push_back(opt);
        return;
    }

    auto configure_arg = option_value(opt, "--configure-arg");
    if (configure_arg.size() > 0) {
        /* Raw, and after everything this build system wrote, so it's
         * the last word on anything it names -- which is why it gets
         * the same check a --define does. */
        refuse_second_answer("--configure-arg", configure_arg);

        _configure_args.push_back(configure_arg);
        _configure_lines.push_back(opt);
        return;
    }

    auto setup_script = option_value(opt, "--setup-script");
    if (setup_script.size() > 0) {
        /* Inside the tree, and spelled so that pasting it after a
         * "$(abspath ...)" in a recipe can't mean anything but a file:
         * it goes into the Makefile as a bare word, so a space would
         * split it, a '$' would be make's, and a quote or a ';' would
         * be the shell's.  That is a narrower list than
         * unsafe_metacharacter() refuses, and deliberately: this is a
         * file name somebody else's tree chose, and every tree that
         * ships one of these calls it something like "configure".
         *
         * Not above the tree either, absolutely or with a "..": a
         * script from somewhere else is a program the SUBPROJECTS
         * didn't name, run with the tree's build directory as its
         * working directory. */
        auto bad = setup_script[0] == '/'
                || setup_script == ".."
                || setup_script.compare(0, 3, "../") == 0
                || setup_script.find("/../") != std::string::npos
                || (setup_script.size() >= 3
                    && setup_script.compare(setup_script.size() - 3, 3,
                                            "/..") == 0);
        for (const auto& c: setup_script) {
            if (isalnum((unsigned char)c) == 0
                && std::string("._/+-").find(c) == std::string::npos)
                bad = true;
        }

        if (bad == true) {
            std::cerr << name() << ": '--setup-script " << setup_script
                      << "' isn't a file inside the tree: it should be a"
                      << " path relative to the top of it, made of"
                      << " letters, digits and '._/+-', like"
                      << " '--setup-script configure'\n";
            abort();
        }

        _setup_script = setup_script;
        _configure_lines.push_back(opt);
        return;
    }

    auto target = option_value(opt, "--target");
    if (target.size() > 0) {
        _ninja_targets.push_back(target);
        _build_lines.push_back(opt);
        return;
    }

    auto jobs = option_value(opt, "--jobs");
    if (jobs.size() > 0) {
        /* Digits, zero included: cargo and cmake refuse a "--jobs 0",
         * but this one is handed to ninja as "-j", and ninja reads
         * "-j 0" as no limit at all, which is something a Configfile
         * might mean. */
        for (const auto& c: jobs) {
            /* Through an unsigned char, which is all isdigit() is
             * defined over: see build_system_cmake's --jobs. */
            if (isdigit((unsigned char)c) == 0) {
                std::cerr << name() << ": '--jobs " << jobs << "' isn't a"
                          << " number of jobs: it should look like"
                          << " '--jobs 8'\n";
                abort();
            }
        }

        _jobs = jobs;
        _build_lines.push_back(opt);
        return;
    }

    if (whole == "--install" || whole == "--no-install") {
        _install = whole == "--install";
        _build_lines.push_back(opt);
        return;
    }

    auto env = option_value(opt, "--env");
    if (env.size() > 0) {
        checked_env("--env", env, "PATH=/opt/gnubin:$(PATH)");

        /* DESTDIR is read out of the environment by the install, so an
         * --env is where a second answer to the prefix is most at
         * home. */
        refuse_second_answer("--env", env);

        /* Both lists: the setup and the build had better see the same
         * environment, or the tree is configured for a machine it
         * isn't built on. */
        _env.push_back(env);
        _configure_lines.push_back(opt);
        _build_lines.push_back(opt);
        return;
    }

    /* The longer flag first, so none of this rests on option_value()
     * refusing to read "--depend-config" as "--depend". */
    auto config_depend = option_value(opt, "--depend-config");
    if (config_depend.size() > 0) {
        _config_depends.push_back(config_depend);
        _configure_lines.push_back(opt);
        return;
    }

    auto depend = option_value(opt, "--depend");
    if (depend.size() > 0) {
        _depends.push_back(depend);
        _configure_lines.push_back(opt);
        _build_lines.push_back(opt);
        return;
    }

    std::cerr << name() << ": unknown CONFIGUREOPTS '" << opt << "'\n"
              << configureopt_help();
    abort();
}

std::string build_system_meson::configure_signature(void) const
{
    /* The configure-side lines as they were written and in the order
     * they were written, and nothing derived from them: see
     * build_system_cmake::configure_signature(). */
    auto out = std::string();
    for (const auto& line: _configure_lines)
        out += line + "\n";

    return out;
}

std::string build_system_meson::build_signature(void) const
{
    /* No MAKEOPS, unlike cmake's: build_system refused every one of
     * them on the way in, so there are none to write down. */
    auto out = std::string();
    for (const auto& line: _build_lines)
        out += line + "\n";

    return out;
}

std::vector<makefile::target::ptr>
build_system_meson::vendored_targets(
    const std::vector<build_system::ptr>& peers,
    const std::string& project_base __attribute__((unused))) const
{
    auto srcdir = source_dir();
    auto build = meson_build_dir();
    auto ninja = ninja_file();
    auto stamp = build_stamp();

    auto label = name();
    for (auto& c: label)
        c = toupper(c);

    /********************************************************************
     * The configuration                                                *
     ********************************************************************/
    /* The prefix as "--prefix=" rather than as a "-Dprefix=", because
     * meson refuses to be handed both and somebody's --configure-arg
     * is far more likely to be written the first way.  Absolute,
     * because meson bakes it into what it builds and a relative one
     * would mean wherever somebody happened to be standing. */
    auto args = std::string(" ")
              + string_utils::quoted("--prefix=$(abspath "
                                     + install_prefix() + ")");

    if (_build_type.size() > 0)
        args += " " + string_utils::quoted("-Dbuildtype=" + _build_type);

    for (const auto& define: _defines)
        args += " " + string_utils::quoted("-D" + define);

    /* Raw, unlike everything above: a --configure-arg is written the
     * way it will appear on the command line. */
    for (const auto& arg: _configure_args)
        args += " " + arg;

    /* A tree's own script runs from inside the build directory, by
     * its absolute path, with everything but the two directories: a
     * configure of the kind that wraps meson works out where its
     * sources are from the path it was run as and where to build from
     * the directory it was run in.  The cd goes in front of the
     * environment rather than after it, so that the variables are the
     * script's rather than the cd's. */
    auto configure = std::string();
    if (_setup_script.size() > 0) {
        /* Asked here rather than where the option arrived, since only
         * a bound build system knows which tree the path is inside. */
        if (access((base() + _setup_script).c_str(), X_OK) != 0) {
            std::cerr << name() << ": '--setup-script " << _setup_script
                      << "' isn't a program in " << srcdir << "\n"
                      << "  it names a file relative to the top of the"
                      << " tree, which has to be there and executable\n";
            abort();
        }

        configure = "mkdir -p " + build + " && cd " + build + " && "
                  + with_env("$(abspath " + srcdir + ")/" + _setup_script
                             + args);
    } else {
        configure = with_env("meson setup" + args + " " + build
                             + " " + srcdir);
    }

    auto config_deps = std::vector<makefile::target::ptr>();
    for (const auto& depend: _config_depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend-config", depend, peers)));

    /* meson runs the compiler while it sets the tree up, so a tree
     * whose toolchain this build makes needs it before it can be
     * configured as well as before it can be built. */
    for (const auto& depend: _depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    config_deps.push_back(std::make_shared<makefile::target>(
        configureopts_file()));

    /* Starting over, build directory and default prefix both, for the
     * reasons build_system_cmake::vendored_targets() gives for its own
     * two "rm -fr"s. */
    auto config_commands = std::vector<std::string>{"rm -fr " + build};
    if (_install == true && private_prefix() == true)
        config_commands.push_back("rm -fr " + install_prefix());

    config_commands.push_back("mkdir -p " + output_dir());
    config_commands.push_back(configure);

    /* A setup that wrote build.ninja before the configure-opts it
     * waits on -- which a fast enough filesystem can make look like
     * the same second -- would otherwise run again on every make. */
    config_commands.push_back("touch $@");

    auto config_target = std::make_shared<makefile::target>(
        ninja,
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
    /* A build directory is marked by the build.ninja meson wrote into
     * it, which is the thing the walk has to know to leave one alone
     * if somebody set the tree up in place. */
    auto dirs = std::vector<std::string>();
    vendored::chase(base(), output_dir() + "/", "build.ninja", true,
                    file_utils::git_ignored_paths(source_dir()), dirs);
    std::sort(dirs.begin(), dirs.end());

    /* The build-side options, written by make out of the recipe that
     * reads them: see cmake.h++ for why it has to be that way round. */
    auto opts_force = std::make_shared<makefile::target>(
        buildopts_force(),
        std::string(),
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        std::vector<std::string>{},
        std::vector<std::string>{
            "Never a file, so the rule below is asked on every build"
        }
    )->as_phony();

    auto write_opts = std::string();
    {
        auto lines = vendored::signature_lines(build_signature());
        if (lines.size() == 0) {
            write_opts = ": > $@.tmp";
        } else {
            write_opts = "printf '%s\\n'";
            for (const auto& line: lines)
                write_opts += " " + vendored::recorded(line);
            write_opts += " > $@.tmp";
        }
    }

    auto opts_target = std::make_shared<makefile::target>(
        buildopts_file(),
        std::string(),
        std::vector<makefile::target::ptr>{opts_force},
        std::vector<makefile::global_targets>{},
        std::vector<std::string>{
            "mkdir -p " + output_dir(),
            write_opts,
            "if cmp -s $@.tmp $@ 2>/dev/null;"
            " then rm -f $@.tmp;"
            " else mv -f $@.tmp $@; fi",
        },
        std::vector<std::string>{
            "The options the vendored build system in " + srcdir + " is"
            " built with, which make compares against the last ones"
        }
    );

    auto build_deps = std::vector<makefile::target::ptr>{config_target};
    if (dirs.size() > 0)
        build_deps.push_back(std::make_shared<makefile::target>(
            vendored::globbed(dirs)));

    for (const auto& depend: _depends)
        build_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    build_deps.push_back(opts_target);

    /* One ninja per target, in order, then the install, then the
     * stamp: the same sequence cmake's build rule runs and for the
     * same reasons. */
    auto build_commands = std::vector<std::string>();
    if (_ninja_targets.size() == 0)
        build_commands.push_back(build_command(""));
    for (const auto& target: _ninja_targets)
        build_commands.push_back(build_command(target));

    if (_install == true)
        build_commands.push_back(build_command("install"));

    build_commands.push_back("mkdir -p " + output_dir());
    build_commands.push_back("date > $@");

    auto build_target = std::make_shared<makefile::target>(
        stamp,
        "BUILD\t" + srcdir,
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

    /* The default prefix goes with the stamp on a "make clean", and a
     * --prefix doesn't: see build_system_cmake::vendored_targets(). */
    if (_install == true && private_prefix() == true)
        build_target = build_target->with_clean_extra(install_prefix());

    return std::vector<makefile::target::ptr>{
        config_target, opts_force, opts_target, build_target
    };
}
