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
#include "../project.h++"
#include "../string_utils.h++"
#include <libmakefile/self_path.h++>
#include <sys/stat.h>
#include <unistd.h>
#include <cctype>
#include <iostream>

build_system_kconfig::build_system_kconfig(const std::string& name)
: build_system(name),
  _defconfig("defconfig"),
  _options(),
  _merges(),
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

build_system::answers build_system_kconfig::already_answered(void) const
{
    auto out = answers();

    /* Every one of these is a make variable rather than an option:
     * kbuild reads them off the sub-make's command line as a
     * "NAME=VALUE", or out of the environment under the same name,
     * and there is no "--name" spelling of any of them.  So the only
     * decoration is the empty one, which answers() already has, and
     * nothing here is abbreviated or spelled with dashes.
     *
     * There is no prefix_option either.  A kbuild tree builds into
     * its output directory and installs nowhere at all unless a
     * --target asks it to, so there is no option here that says where
     * an install goes -- and refuse_second_answer() says that rather
     * than naming an option nobody could write. */

    /* Where an install goes, one per install target a kbuild tree
     * has.  The list is the kernel's own: these are the variables
     * Documentation/kbuild/kbuild.rst writes down as the ones that
     * say where something installed lands, and they are written out
     * rather than matched by shape because "INSTALL_MOD_STRIP" starts
     * the same way as two of them and says nothing about where
     * anything goes.
     *
     * The install here runs during "make" rather than during "make
     * install" -- a --target modules_install is a goal of the build
     * stamp like any other -- so one of these written in a Configfile
     * is a plain "make" writing wherever the line pointed, which for
     * INSTALL_PATH and INSTALL_MOD_PATH means "/boot" and "/" by
     * default.
     *
     * DESTDIR is neither kbuild's nor this build system's, and it
     * belongs with them for the reason it belongs with autotools'
     * and cmake's: it is make's own convention for the thing pasted
     * onto the front of an install, every kconfig-derived tree that
     * installs anything honours it, and a command-line variable
     * reaches every sub-make the tree starts.
     *
     * INSTALL_MOD_DIR is deliberately not here.  It names a
     * directory under MODLIB rather than a place of its own -- kbuild
     * joins it to "$(MODLIB)/", so an absolute value comes out as
     * ".../lib/modules/$(KERNELRELEASE)//tmp/x" and still lands
     * inside -- and refusing it would be refusing its default,
     * "extra", which is a value somebody has every right to change. */
    for (const auto& variable: {
            "INSTALL_MOD_PATH", "MODLIB", "INSTALL_PATH",
            "INSTALL_HDR_PATH", "INSTALL_DTBS_PATH", "DESTDIR"})
        out.destinations.push_back(
            {variable, "says where an install target of this tree writes"});

    /* And where the tree builds, which this build system already
     * wrote on the same command line: vendored_targets() puts an
     * "O=$(abspath ...)" on every sub-make it composes, and
     * makeopt_flags() comes after it -- so a second one wins, quietly,
     * and every path pconfigure wrote down about this tree points at
     * a directory the tree never used.  What comes of it is a whole
     * kernel build somewhere "make distclean" does not name, a
     * .config the configure rule says it wrote and didn't, and a
     * build stamp that says a tree was built that has nothing in it.
     *
     * KBUILD_OUTPUT is the same statement spelled for the
     * environment, which is what kbuild.rst calls it and what an
     * --env would set. */
    out.directories.push_back(
        {"O", "says where the tree builds"});
    out.directories.push_back(
        {"KBUILD_OUTPUT",
         "says where the tree builds, being kbuild's environment spelling"
         " of 'O'"});

    /* "M" is the same statement about a smaller tree: kbuild.rst
     * documents "make -C /path/to/kernel M=$PWD" as how an external
     * module gets built against a kernel tree that isn't its own, and
     * a Configfile that wrote "M=" here would send that module's build
     * wherever the line pointed rather than into this project's object
     * directory -- the same hazard "O=" already refuses, one level
     * down. KBUILD_EXTMOD is the same thing spelled for the
     * environment, the way KBUILD_OUTPUT is to "O". */
    out.directories.push_back(
        {"M", "says where the tree builds an external module"});
    out.directories.push_back(
        {"KBUILD_EXTMOD",
         "says where the tree builds an external module, being kbuild's"
         " environment spelling of 'M'"});

    /* KCONFIG_CONFIG is the third thing this build system already
     * knows the shape of, having set it itself a few lines down in
     * vendored_targets(): it is what kbuild calls the .config it
     * reads and writes, defaulting to ".config" in the output
     * directory this build system already chose.  A Configfile that
     * also wrote it -- on the sub-make's command line, in the
     * environment, or as a --target's variable -- would move the file
     * this build system reads back after configuring and writes into
     * the fragment kbuild_output() and config_file() both point at,
     * to wherever the line said instead. */
    out.directories.push_back(
        {"KCONFIG_CONFIG", "says where the tree's .config lives"});

    return out;
}

void build_system_kconfig::take_makeopt(const std::string& opt)
{
    refuse_second_answer("MAKEOPS", opt);
}

bool build_system_kconfig::handle_configureopt(const std::string& opt)
{
    auto defconfig = option_value(opt, "--defconfig");
    if (defconfig.size() > 0) {
        /* A goal on the sub-make's command line is a goal or it is a
         * variable, and make decides which by whether there is an '='
         * in it: "make INSTALL_MOD_PATH=/tmp/x" asks for the default
         * goal with that variable set.  So a defconfig goes through
         * the same door a --make-var does. */
        refuse_second_answer("--defconfig", defconfig);

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
        /* What a variable on the sub-make's command line may not say
         * is build_system::refuse_second_answer()'s question.  Asked
         * here as well as in take_makeopt(), which add_makeopt()
         * reaches anyway, so that the diagnostic names the option the
         * Configfile actually wrote rather than the MAKEOPS this
         * shares a list with. */
        refuse_second_answer("--make-var", make_var);

        /* The same thing a MAKEOPS says, spelled the way the options
         * are.  One list and one order, since two lists would mean an
         * argument about which of them make hears last -- and the
         * last one is the one that wins. */
        add_makeopt(make_var);
        return true;
    }

    auto env = option_value(opt, "--env");
    if (env.size() > 0) {
        /* What an --env is allowed to look like is one question with
         * one answer for every build system here, so it is asked in
         * one place: see build_system::checked_env(). */
        checked_env("--env", env, "PATH=/opt/gnubin:$(PATH)");

        /* And what it may not say is the other one question with one
         * answer: kbuild reads where it builds and where it installs
         * out of the environment just as readily as off a command
         * line, so an --env is a spelling of the same statement a
         * --make-var makes. */
        refuse_second_answer("--env", env);

        _env.push_back(env);
        return true;
    }

    auto make_target = option_value(opt, "--target");
    if (make_target.size() > 0) {
        /* A goal and a variable arrive on the same command line and
         * are told apart by an '=', which is why this is asked of a
         * --target at all: '--target INSTALL_MOD_PATH=/tmp/x' names
         * no goal, sets a variable, and gets the tree's default goal
         * built with an install destination nobody here decided. */
        refuse_second_answer("--target", make_target);

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
     * what a --make-var is for.
     *
     * Quoted whole, name and all, because that is what this is: one
     * variable on a make command line, which is the same thing every
     * --make-var beside it is and so wants the same treatment
     * makeopt_flags() gives those.  A CROSS_COMPILE is a prefix stuck
     * on the front of a program name, so it is a path as often as it
     * is a word -- "/opt/my tools/bin/riscv64-unknown-elf-" is a
     * toolchain somebody unpacked where they unpacked it -- and
     * unquoted that line hands the sub-make a CROSS_COMPILE worth
     * "/opt/my" and then a "tools/bin/riscv64-unknown-elf-" that make
     * reads as a target it was asked to build.  What comes of it is a
     * tree built with a toolchain prefix nobody wrote, or a make that
     * stops on a goal nobody asked for, from a Configfile line that
     * was accepted without a murmur.
     *
     * The value is not taken apart by that, so a CROSS_COMPILE that
     * was written as "$(abspath toolchain/bin/riscv64-)" still gets
     * make's expansion and still means what it says. */
    if (wants_cross_compile() == true && ctx()->cross_compile.size() > 0) {
        auto flag = std::string("CROSS_COMPILE=");

        auto given = false;
        for (const auto& make_var: makeopts())
            if (make_var.compare(0, flag.size(), flag) == 0)
                given = true;

        if (given == false)
            out += " " + string_utils::quoted(flag + ctx()->cross_compile);
    }

    return out + makeopt_flags();
}

std::string build_system_kconfig::with_env(const std::string& command) const
{
    auto out = std::string();

    for (const auto& env: _env) {
        /* The value is quoted and the name is not, which is the only
         * way round that works: a shell reads "NAME=VALUE cmd" as an
         * assignment in front of a command, and 'NAME=VALUE' quoted
         * whole stops being an assignment and becomes the name of a
         * program nobody has.
         *
         * Left unquoted altogether -- which is how this was first
         * written -- an "--env KCFLAGS=-O2 -g" hands the shell a "-g"
         * to run as a command of its own once the sub-make has
         * finished, so the recipe dies with "-g: command not found"
         * at build time having been accepted without a murmur at
         * configure time.  Worse is the value that happens to name a
         * program: then nothing fails, and a build quietly runs a
         * word out of a Configfile.
         *
         * string_utils::quoted() leaves the value exactly as it was
         * written, so an "--env PATH=/opt/gnubin:$(PATH)" still gets
         * make's expansion and still means what it says -- which is
         * the whole reason these are worth having.
         *
         * There is an '=' in every one of these, and a name a
         * shell reads as a name in front of it, because an --env
         * without either never got past checked_env(). */
        auto equals = env.find('=');
        out += env.substr(0, equals + 1)
             + string_utils::quoted(env.substr(equals + 1))
             + " ";
    }

    return out + command;
}

std::string build_system_kconfig::based_file(const std::string& flag,
                                             const std::string& path) const
{
    /* A prerequisite is written into the Makefile of the project that
     * asked for it, and that Makefile has to keep working when
     * somebody runs make in that project rather than above it.  Only
     * a path that stays inside the project can be rewritten to say
     * both of those things at once, so one that climbs out is a
     * question with two answers rather than a path -- which is
     * build_system::checked_project_path()'s question, asked there
     * and not here.
     *
     * It used to be asked here, of the resolved path rather than of
     * what the Configfile wrote, and that is the difference between a
     * rule and a coincidence: a '--merge-config ../frag.config' in a
     * subproject resolves to the parent's 'frag.config', which climbs
     * out of nothing and was accepted -- and the fragment then
     * reached the Makefile as a bare 'frag.config' with no prefix
     * variable in front of it, so the same line was legal from the
     * top and refused from inside the subproject. */
    auto out = checked_project_path(flag, path, "configs/extra.config");

    struct stat buf;
    if (stat(out.c_str(), &buf) != 0 || S_ISREG(buf.st_mode) == false) {
        std::cerr << name() << ": '" << flag << " " << path << "' names '"
                  << out << "', which isn't a file\n";
        abort();
    }

    return out;
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
           "  '--depend PATH' waits for something else before configuring"
           " and building\n"
           "  '--depend-config PATH' waits for something else before"
           " configuring\n";
}

std::string build_system_kconfig::configure_signature(void) const
{
    auto out = build_system::configure_signature();

    /* CROSS_COMPILE isn't a CONFIGUREOPTS, but make_var_flags() puts
     * it on the command line of every sub-make this writes -- so a
     * project that changed which machine it builds for has changed
     * how the tree gets configured just as surely as a --make-var
     * would have.  A tree that refuses to be told this at all has no
     * business being reconfigured over it. */
    if (wants_cross_compile() == true)
        out += "CROSS_COMPILE=" + ctx()->cross_compile + "\n";

    return out;
}

void build_system_kconfig::take_configureopt(const std::string& opt)
{
    if (handle_configureopt(opt) == true)
        return;

    std::cerr << name() << ": unknown CONFIGUREOPTS '" << opt << "'\n"
              << configureopt_help();
    abort();
}

/* Where make will be running, spelled absolutely.  A kbuild tree
 * writes the paths it read as absolute ones, and this is the only
 * thing that can turn one of those back into a path this build can
 * use -- or recognise it as naming a toolchain header somewhere else
 * entirely. */
static std::string here(void)
{
    auto buffer = std::vector<char>(4096);
    while (getcwd(&buffer[0], buffer.size()) == NULL) {
        if (errno != ERANGE) {
            std::cerr << "kconfig: unable to find the current directory\n";
            abort();
        }
        buffer.resize(buffer.size() * 2);
    }

    return std::string(&buffer[0]);
}

std::vector<makefile::target::ptr>
build_system_kconfig::vendored_targets(
    const std::vector<build_system::ptr>& peers,
    const std::string& project_base) const
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
    /* Through "$(wildcard)", as one prerequisite rather than
     * hundreds, because these were worked out by looking at the tree
     * and the tree moves.  kconfig_deps promises only the paths that
     * existed at the moment of configuring, and every submodule bump
     * deletes some -- after which make has a prerequisite nothing can
     * build and refuses to build anything at all, not just this
     * subproject.  The way out is "make reconfigure", whose name
     * appears nowhere in the error it prints.
     *
     * $(wildcard) is re-expanded every run, so a file that has gone
     * away stops being named and one that comes back starts again. */
    auto config_deps = std::vector<makefile::target::ptr>();
    if (deps.config.size() > 0)
        config_deps.push_back(std::make_shared<makefile::target>(
            "$(wildcard " + string_utils::join(deps.config, " ") + ")"));
    for (const auto& path: kconfig_deps::defconfig_files(base(), _defconfig))
        config_deps.push_back(std::make_shared<makefile::target>(path));
    for (const auto& depend: _config_depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend-config", depend, peers)));

    /* Everything the build waits for, the configuration waits for
     * too.  Configuring a kbuild tree is a sub-make of that tree with
     * the project's CROSS_COMPILE on its command line, and Kconfig
     * asks the compiler what it can do while it is deciding what the
     * .config says -- so a tree whose toolchain this build produces
     * needs that toolchain before it can be configured, not just
     * before it can be built.
     *
     * Hanging these off the build alone is what made a fresh checkout
     * take two passes of make: the first one configured the tree
     * against a compiler that wasn't there yet and wrote down the
     * answers Kconfig gives when it can't run one. */
    for (const auto& depend: _depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    /* What this run was told, which has to be a prerequisite because
     * nothing else here is: every other file above is one the tree or
     * the project already had, so a build reconfigured with different
     * options would find all of them exactly as it left them and do
     * nothing.  pconfigure writes this one, and rewrites it only when
     * it says something different than it did last time.
     *
     * It hangs off the configuration rather than off the build
     * because the build already waits for the configuration, so this
     * one file covers both -- and because the alternative is two
     * files and a standing argument about which half of the state
     * each new option belongs in, when --env, --make-var and
     * CROSS_COMPILE all land in both.  The price is that a --target,
     * which only the build reads, reconfigures too: that costs one
     * sub-make of a defconfig that writes back the file that was
     * already there. */
    config_deps.push_back(std::make_shared<makefile::target>(
        configureopts_file()));

    /* The goal is quoted, which is what everything else a
     * CONFIGUREOPTS wrote gets on its way into a recipe.  One option
     * is one goal, so the spaces in it are characters of a name
     * rather than a list this is allowed to split on -- and a
     * semicolon in it, left raw, ends the recipe's command and hands
     * the shell whatever came after to run as a program of its own.
     * A "--defconfig x; rm -rf ~" was read without a murmur at
     * configure time and run by a plain "make", which then said the
     * build had succeeded. */
    auto config_commands = std::vector<std::string>{
        "mkdir -p " + output,
        submake + " " + string_utils::quoted(_defconfig),
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
        /* The fragment is quoted where it lands in the recipe and
         * bare where it lands in the prerequisite list, because those
         * are two different readers: a prerequisite is a make word
         * and has no quoting at all, while a recipe is a shell
         * command and a path that isn't quoted there is however many
         * words the shell decides it is.  So this is the same thing
         * every other value a CONFIGUREOPTS wrote gets, for the same
         * reason, and it costs nothing: a quote is one of the
         * characters path_prefix::rewrite() reads as the end of one
         * word and the start of the next, so a subproject's fragment
         * is still named through that project's own prefix variable.
         *
         * What it is NOT is the answer to a path with shell syntax in
         * it.  checked_project_path() already refuses the space, the
         * '$', the absolute path and the "..", and it has no opinion
         * about a ';' -- and a ';' in one of these reaches make on
         * the prerequisite line above, where make reads it as the
         * start of an inline recipe rather than as part of a
         * filename.  That is one question with one answer for every
         * path a Configfile writes, in the one place all of them go
         * through, and it is not this one. */
        for (const auto& merge: _merges) {
            auto path = based_file("--merge-config", merge);
            command += " " + string_utils::quoted(path);
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

            /* The name and the value are each quoted, and each is one
             * argument to the tree's own program however many spaces
             * are in it.  Left raw -- which is how this was written --
             * a '--configure CONFIG_X; rm -rf ~ =y' ends the recipe's
             * command at the semicolon and hands the shell the rest
             * to run as a program of its own: read without a murmur
             * at configure time, run by a plain "make", and reported
             * as a build that succeeded.
             *
             * It is the same decision autotools and cmake made about
             * a --target, for the same reason, and it costs the same
             * thing: one option says one name and one value, so
             * neither of them is a place to write two. */
            auto name = string_utils::quoted(option.name);

            if (option.value == "y")
                command += " --enable " + name;
            else if (option.value == "m")
                command += " --module " + name;
            else if (option.value == "n")
                command += " --disable " + name;
            else if (option.value.size() > 1
                     && option.value[0] == '"'
                     && option.value[option.value.size() - 1] == '"')
                /* A value that was written with quotes around it is a
                 * string, and a string symbol is the one kind whose
                 * value goes into the .config with quotes back on --
                 * which the tree's own program does and we don't.
                 * The quotes the Configfile wrote are what says which
                 * kind this is, so they are taken off here and the
                 * rest is quoted the way every other value is: the
                 * tree's program sees exactly what it saw before,
                 * which is the string with no quotes round it and in
                 * one argument however many spaces are in it.
                 *
                 * Leaving the '"' on and letting the shell take it
                 * off is what this did before, and it is the same
                 * hole one character narrower: a value of '"a"; rm
                 * -rf ~; "' starts and ends with a '"' and is a
                 * command in the middle. */
                command += " --set-str " + name + " "
                         + string_utils::quoted(
                               option.value.substr(1,
                                                   option.value.size() - 2));
            else
                command += " --set-val " + name + " "
                         + string_utils::quoted(option.value);

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

    /* Everything above is a guess about what configuring this tree
     * reads.  The tree knows, and says so: it writes a list of the
     * files that went into its configuration, because its own build
     * needs one.  That file only exists once the tree has been
     * configured, so what reads it is a program the build runs, and
     * what it produces is a piece of Makefile this one includes.
     *
     * The context is written now because it is the fragment's only
     * prerequisite, and that is what makes the whole thing terminate:
     * it is a file nothing in this Makefile builds, so the fragment
     * can go out of date at most once per configure.
     *
     * The same command runs again at the end of the two recipes that
     * could have changed the answer.  That is what keeps a clean
     * checkout to one pass instead of two -- by the time the first
     * make has finished, the fragment says what the tree just said,
     * rather than what it had said before it was built. */
    /* Named for the project that wrote them, the way everything a
     * configure leaves for a build is.  A vendored tree inside a
     * subproject is described twice -- once by a run at the top of
     * the tree and once by a run inside the subproject -- and the two
     * descriptions are of the same tree from different places.  One
     * name for both would mean the fragment a build includes was
     * whatever the other configure had last put there, which is a set
     * of paths pointing one directory away from anything real. */
    auto suffix = project::base_suffix(project_base);
    auto deps_context = output_dir() + "/config-deps-context" + suffix;
    auto deps_fragment = output_dir() + "/config-deps" + suffix + ".mk";

    auto say = [](const std::string& key, const std::string& value)
        { return key + " " + value + "\n"; };

    auto context = std::string();
    context += say("tree", srcdir);
    context += say("output", output_dir());
    context += say("target", config);
    context += say("fragment", deps_fragment);
    for (const auto& candidate: config_dep_files())
        context += say("dep-file", candidate);
    context += say("dep-root", base());

    /* Only a project a parent can include has anything to say here:
     * the fragment is written during the build, so it is the only
     * thing in this Makefile that has to do its own rewriting. */
    if (project_base.size() > 0) {
        context += say("base", project_base);
        context += say("variable", project::prefix_variable(project_base));
    }

    file_utils::mkdir_p(output_dir());
    file_utils::write_if_changed(deps_context, context);

    auto reread = makefile::tool_command("psubdeps")
                + " --context " + deps_context;
    config_commands.push_back(reread);
    config_commands.push_back("touch $@");

    /* And the same again for the other question, which is what the
     * tree read while it was BUILDING rather than while it was being
     * configured.  A separate context because it is a separate
     * answer, landing on a separate rule: one file per question means
     * the rule that wants the cheap answer does not pay for the
     * expensive one, which for a kernel is a walk of ten thousand
     * files.
     *
     * A tree that scatters nothing to read gets none of this and
     * keeps the guess, which is the only thing there is for it. */
    auto build_deps_root = build_dep_root();
    auto build_context = output_dir() + "/build-deps-context" + suffix;
    auto build_fragment = output_dir() + "/build-deps" + suffix + ".mk";
    auto reread_build = std::string();

    if (build_deps_root.size() > 0) {
        auto build_ctx = std::string();
        build_ctx += say("tree", srcdir);
        build_ctx += say("output", output_dir());
        build_ctx += say("target", stamp);
        build_ctx += say("fragment", build_fragment);
        build_ctx += say("cmd-root", build_deps_root);
        build_ctx += say("root", here());

        if (project_base.size() > 0) {
            build_ctx += say("base", project_base);
            build_ctx += say("variable",
                             project::prefix_variable(project_base));
        }

        file_utils::write_if_changed(build_context, build_ctx);

        reread_build = makefile::tool_command("psubdeps")
                     + " --context " + build_context;
    }

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
    if (deps.build.size() > 0)
        build_deps.push_back(std::make_shared<makefile::target>(
            "$(wildcard " + string_utils::join(deps.build, " ") + ")"));
    /* Said again here rather than left to the configuration this
     * build already waits for, so that the rule that names the thing
     * being built is the rule that says what it was built out of. */
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

    /* Each one quoted, which is the same decision autotools and cmake
     * made about their own --target and is here for the same reason:
     * one option is one target.  That is what the option says it is
     * -- a tree that wants two of them writes --target twice, and
     * they are asked for one at a time on purpose -- so the spaces in
     * one of them are characters of a name rather than a list this is
     * allowed to split on.  Left raw, a semicolon in a target ends
     * the recipe's command and hands the shell whatever came after it
     * to run as a program of its own: a Configfile read without a
     * murmur at configure time and a plain "make" that runs it and
     * then reports success.
     *
     * The paths around it stay as they are, here and everywhere else
     * in this file: every recipe line goes through
     * path_prefix::rewrite() on its way into the Makefile, which is
     * what lets a subproject's rules name the same files from above
     * and from inside. */
    for (const auto& make_target: _make_targets)
        build_commands.push_back(
            submake + " " + string_utils::quoted(make_target));
    build_commands.push_back("mkdir -p " + output_dir());
    build_commands.push_back(reread);
    if (reread_build.size() > 0)
        build_commands.push_back(reread_build);
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

    /* The same hole the C++ fragments had, in the same shape: this
     * fragment is what one version of psubdeps made of what the
     * vendored tree said it read, and rebuilding psubdeps did not
     * invalidate it.  The context beside it is a prerequisite already,
     * so a psubdeps that moved was noticed; a psubdeps rebuilt where
     * it stood was not, which is every build of a tree that vendors
     * pconfigure.
     *
     * Absolute, out of tool_command(), and wrapped in "$(wildcard)",
     * for the reasons written out at length over language_cxx::
     * deps_source(): absolute so make cannot mistake it for the
     * in-tree target it does have a rule for and try to link it
     * while it is still working out what to include, wrapped so that
     * "make clean" having taken it away is a build with no opinion
     * rather than a build that stops.  It does not disturb what the
     * rule above it is for: an absolute path with no rule is a
     * timestamp, it cannot go out of date during a make, so this
     * fragment can still be remade at most once and the remaking
     * still terminates. */
    auto psubdeps = std::make_shared<makefile::target>(
        "$(wildcard " + makefile::tool_command("psubdeps") + ")");

    auto deps_target = std::make_shared<makefile::target>(
        deps_fragment,
        "DEPS\t" + srcdir,
        std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(deps_context),
            psubdeps
        },
        std::vector<makefile::global_targets>{
            makefile::global_targets::CLEAN
        },
        std::vector<std::string>{
            "mkdir -p $(dir $@)",
            reread
        },
        std::vector<std::string>{
            "What the vendored build system in " + srcdir + " said it"
            " read while it was being configured"
        }
    )->as_included();

    auto out = std::vector<makefile::target::ptr>{
        config_target, build_target, deps_target};

    if (reread_build.size() > 0)
        out.push_back(std::make_shared<makefile::target>(
            build_fragment,
            "DEPS\t" + srcdir,
            std::vector<makefile::target::ptr>{
                std::make_shared<makefile::target>(build_context),
                psubdeps
            },
            std::vector<makefile::global_targets>{
                makefile::global_targets::CLEAN
            },
            std::vector<std::string>{
                "mkdir -p $(dir $@)",
                reread_build
            },
            std::vector<std::string>{
                "What the vendored build system in " + srcdir + " said it"
                " read while it was being built"
            }
        )->as_included());

    return out;
}
