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

#include "autotools.h++"
#include "../file_utils.h++"
#include "../string_utils.h++"
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <iostream>

build_system_autotools::build_system_autotools(const std::string& name)
: build_system(name),
  _prefix(),
  _configure_args(),
  _env(),
  _make_targets(),
  _depends(),
  /* An install by default, because the reason to vendor a tool tree
   * is to run the tool, and the only layout an autotools tree
   * documents is the one it installs into.  A build directory is
   * objects, libtool wrappers and whatever else the tree felt like
   * leaving there, and which of those is the program is a question
   * the tree has never promised to answer the same way twice. */
  _install(true),
  _autoreconf(),
  _no_autoreconf(false)
{
}

build_system* build_system_autotools::clone(void) const
{
    /* Everything a CONFIGUREOPTS puts in here is a string, a bool or
     * a vector of strings, so the copy constructor has already made
     * the deep copy this promises to make.  It stays that way as long
     * as nobody puts a pointer to something shared in the class. */
    return new build_system_autotools(*this);
}

bool build_system_autotools::can_build(const std::string& base) const
{
    /* The two states one of these trees turns up in.  A release
     * tarball ships the generated configure and is ready to run; a
     * checkout usually ships only the configure.ac it's made from,
     * because a generated file in version control is a merge conflict
     * waiting to happen.  Either one is an autotools tree and the
     * difference is only in what has to be done first.
     *
     * "configure.in" is what configure.ac was called before 2001.
     * Nothing writes a new one, and trees that were already old then
     * still carry theirs.
     *
     * Nothing here asks for a Makefile.am or a Makefile.in.  A tree
     * with automake has the first, a tarball of the same tree has the
     * second, and a tree that writes its own Makefile.in by hand --
     * which is more of them than anybody expects -- has neither until
     * configure has run.  Asking would turn a real distinction into a
     * guess about which vintage of tree this is. */
    if (access((base + "configure").c_str(), R_OK) == 0)
        return true;
    if (access((base + "configure.ac").c_str(), R_OK) == 0)
        return true;

    return access((base + "configure.in").c_str(), R_OK) == 0;
}

build_system::answers build_system_autotools::already_answered(void) const
{
    auto out = answers();

    /* Three spellings reach a generated configure and they are one
     * statement: "--bindir=DIR" among its flags, a "bindir=DIR"
     * variable beside them, and the single-dash "-bindir=DIR" that it
     * also takes.  The two-word "--bindir DIR" is the first of these
     * with the directory in the next argument, so catching the word
     * is catching the pair. */
    out.decorations = std::vector<std::string>{"", "-", "--"};

    /* And autoconf writes out every truncation of every one of them,
     * which is what a list of whole names walked straight past:
     * "--pre=/usr/local" is "--prefix=/usr/local" with three
     * characters taken off, and it was accepted by a check that
     * refused the other.  See the comment on answers::abbreviated for
     * what refusing a name that is a prefix of one of these costs. */
    out.abbreviated = true;

    /* autoconf spells its options with dashes and its variables with
     * underscores: "--exec-prefix" and "exec_prefix" are one thing,
     * and setting it alone moves the programs and the libraries
     * without touching the prefix. */
    out.dashed = true;

    out.prefix_option = "--prefix DIR";

    /* A relative value is not a way of saying "under the prefix"
     * here.  The GNU directory variables are absolute paths by
     * construction -- their defaults are written in terms of
     * ${prefix} and ${exec_prefix}, which configure expands -- and a
     * relative one reaches the tree's own Makefile as it was written,
     * where the install rule reads it from the directory make is
     * standing in.  That is the build directory rather than the
     * prefix, so a "--bindir=bin" installs somewhere nothing in this
     * build goes looking, which is the thing all of this exists to
     * stop rather than a narrower spelling of it. */
    out.relative_subdirectories = false;

    /* Where the whole install goes.  DESTDIR is make's rather than
     * autoconf's and belongs with them for the same reason: it is
     * pasted onto the front of every one of the others while the
     * install is running, and an install here runs during "make". */
    for (const auto& variable: {"prefix", "exec_prefix", "DESTDIR"})
        out.destinations.push_back(
            {variable, "says where the tree installs to"});

    /* And where one kind of file goes inside it.  These are the
     * directory variables the GNU coding standards define, which is
     * exactly the list autoconf writes a "--name" option for and
     * automake writes a "$(name)" into its install rules for.
     *
     * The list is written out rather than guessed at because there is
     * no shape that tells these from the several hundred other
     * options a configure takes: "--sbindir" is one of these and
     * "--with-sysroot" is not, and they look identical.  A guess that
     * was wrong in one direction would be a build installing where
     * nobody asked; wrong in the other, an option nobody could write
     * at all. */
    for (const auto& variable: {
            "bindir", "sbindir", "libexecdir", "datarootdir", "datadir",
            "sysconfdir", "sharedstatedir", "localstatedir", "runstatedir",
            "includedir", "oldincludedir", "docdir", "infodir", "htmldir",
            "dvidir", "pdfdir", "psdir", "libdir", "localedir", "mandir"})
        out.subdirectories.push_back(
            {variable, "says where part of the install goes"});

    /* And the one directory this build system names that isn't about
     * installing at all.  configure works out where its sources are
     * from the path it was run as, which is what "$(abspath
     * sub)/configure" above is for -- and "--srcdir" is that said a
     * second time, from a Configfile, about a tree no SUBPROJECTS
     * mentioned.  What it buys somebody who writes it is a build of a
     * tree this project never names, out of a directory nothing here
     * cleans, under the name of the one it does.
     *
     * The other half of an out-of-tree build -- which directory the
     * tree builds in -- has no option to say it twice with: configure
     * builds where it is run, and where it is run is the "cd" in
     * front of it rather than a word on its command line. */
    out.directories.push_back(
        {"srcdir", "says which tree gets configured"});

    /* And the one file this build system names that isn't a directory
     * at all.  A generated configure's "--cache-file=PATH" (or a bare
     * "cache_file=PATH" variable, since autoconf reads that spelling
     * of it too) both creates and overwrites the file at PATH with
     * whatever it found out about the machine it ran on -- real
     * behaviour of a real autoconf, not a hazard borrowed from
     * somewhere else.  Left unrefused, a Configfile with one of these
     * writes wherever it pointed on every configure, which for a path
     * outside this project's object directory is a file "make
     * distclean" never hears about and a build that leaves something
     * behind every time it runs.  The default, "config.cache", is
     * never written at all unless one of these names it -- so this
     * refuses a place, not a feature nobody asked for. */
    for (const auto& variable: {"cache-file", "cache_file"})
        out.directories.push_back(
            {variable, "says where the tree caches what configure found"
                       " out"});

    return out;
}

bool build_system_autotools::handle_configureopt(const std::string& opt)
{
    /* The three that take no value are matched outright, since
     * option_value() answers "" both for a flag that isn't this one
     * and for one that was given nothing -- which is the right answer
     * for an option that has a value and no answer at all for one
     * that hasn't. */
    if (opt == "--install") {
        _install = true;
        return true;
    }

    if (opt == "--no-install") {
        _install = false;
        return true;
    }

    if (opt == "--no-autoreconf") {
        /* Both halves of this pair write both fields, which is what
         * makes them last-one-wins the way --install and --no-install
         * are.  They have to be: the shape somebody actually writes
         * is a "--no-autoreconf" under a BUILD_SYSTEMS, inherited by
         * every autotools subproject, and then a per-subproject
         * "--autoreconf ./autogen.sh" for the one tree that does need
         * bootstrapping.  Checking one field before the other instead
         * would make that later line do nothing at all, and the tree
         * would then be refused for having no configure and nothing
         * to make one -- advice about an option the author did
         * write. */
        _no_autoreconf = true;
        _autoreconf.clear();
        return true;
    }

    auto prefix = option_value(opt, "--prefix");
    if (prefix.size() > 0) {
        /* Nothing is asked about it here.  Where a prefix may point
         * is one question with one answer for every vendored build
         * system, and answering the easy half of it here -- the half
         * that needs nothing but the string -- is how it came to have
         * three answers in the first place.  install_prefix() asks,
         * once the project this was bound to is known. */
        _prefix = prefix;
        return true;
    }

    auto flag = option_value(opt, "--configure-flag");
    if (flag.size() > 0) {
        if (flag[0] != '-') {
            std::cerr << name() << ": '--configure-flag " << flag << "' isn't"
                      << " a flag: it should look like"
                      << " '--configure-flag --enable-foo'\n"
                      << "  a NAME=VALUE for configure's command line is a"
                      << " '--configure-var' instead\n";
            abort();
        }

        /* Said twice, the two would reach configure as two arguments
         * about where to install and the tree would take whichever
         * came last.  Which one that is depends on the order this
         * file composes them in, which is not a thing anybody reading
         * the Configfile can see.
         *
         * Every spelling of it rather than "--prefix" alone, which is
         * what this used to ask: "--bindir=/usr/local/bin" sailed
         * through and a plain "make" installed there. */
        refuse_second_answer("--configure-flag", flag);

        _configure_args.push_back(flag);
        return true;
    }

    auto var = option_value(opt, "--configure-var");
    if (var.size() > 0) {
        /* Without the '=' this is a word configure would read as a
         * flag it has never heard of, and configure's answer to a
         * flag it has never heard of is a warning and a build that
         * carries on without it. */
        if (var.find('=') == std::string::npos) {
            std::cerr << name() << ": '--configure-var " << var << "' has no"
                      << " value: it should look like"
                      << " '--configure-var YACC=/opt/bin/bison'\n";
            abort();
        }

        /* A generated configure reads a "name=value" on its command
         * line as an assignment, whatever the name is, so this is
         * the same statement --configure-flag makes with dashes in
         * front of it and gets the same answer. */
        refuse_second_answer("--configure-var", var);

        _configure_args.push_back(var);
        return true;
    }

    auto make_var = option_value(opt, "--make-var");
    if (make_var.size() > 0) {
        /* And the third spelling: a variable on the command line of
         * the make that installs beats whatever the tree's own
         * Makefile says about it, which is the whole reason to write
         * one.  Asked here as well as in take_makeopt() so that the
         * diagnostic names the line that was written rather than the
         * MAKEOPS it is the same as. */
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

        /* And the fourth spelling of where the tree installs, which
         * is the environment -- the channel make imports a variable
         * from in the first place.  DESTDIR was refused as a
         * --configure-var, as a --make-var and as a MAKEOPS and taken
         * here, which is worse than never having refused it: three
         * closed doors and an open one read as a closed door, and
         * what came through this one was the whole install, staged
         * wherever it pointed, on a plain "make". */
        refuse_second_answer("--env", env);

        _env.push_back(env);
        return true;
    }

    auto make_target = option_value(opt, "--target");
    if (make_target.size() > 0) {
        _make_targets.push_back(make_target);
        return true;
    }

    auto autoreconf = option_value(opt, "--autoreconf");
    if (autoreconf.size() > 0) {
        /* The other half of the pair above: naming the program that
         * makes the configure takes back a "--no-autoreconf" that
         * said nothing does. */
        _autoreconf = autoreconf;
        _no_autoreconf = false;
        return true;
    }

    auto depend = option_value(opt, "--depend");
    if (depend.size() > 0) {
        _depends.push_back(depend);
        return true;
    }

    return false;
}

std::string build_system_autotools::configureopt_help(void) const
{
    return "  '--prefix DIR' says where the tree installs to\n"
           "  '--configure-flag --enable-foo' passes one argument to"
           " ./configure\n"
           "  '--configure-var NAME=VALUE' puts a variable on"
           " ./configure's command line\n"
           "  '--env NAME=VALUE' puts a variable in the environment it runs"
           " in\n"
           "  '--make-var NAME=VALUE' puts a variable on the sub-make's"
           " command line\n"
           "  '--target NAME' asks the tree for a target rather than for its"
           " default\n"
           "  '--install' and '--no-install' say whether 'make install' is"
           " part of building it\n"
           "  '--autoreconf CMD' says what makes the tree's ./configure, and"
           " '--no-autoreconf' that nothing does\n"
           "  '--depend PATH' waits for something else before configuring"
           " and building\n";
}

void build_system_autotools::take_makeopt(const std::string& opt)
{
    refuse_second_answer("MAKEOPS", opt);
}

void build_system_autotools::take_configureopt(const std::string& opt)
{
    if (handle_configureopt(opt) == true)
        return;

    std::cerr << name() << ": unknown CONFIGUREOPTS '" << opt << "'\n"
              << configureopt_help();
    abort();
}

std::string build_system_autotools::install_prefix(void) const
{
    /* Beside the build rather than inside it, since the build
     * directory is the tree's and a prefix underneath it would be a
     * directory the tree's own "make clean" is entitled to have an
     * opinion about. */
    if (_prefix.size() == 0)
        return output_dir() + "/prefix";

    /* Everywhere else the question is the same question every build
     * system here asks about an install prefix, so it is asked in one
     * place and answered one way: see build_system::install_dir() for
     * what the cleaning targets do with this directory, and
     * build_system::checked_install_dir() for what a prefix is not
     * allowed to name and why. */
    return checked_install_dir("--prefix", _prefix);
}

std::string build_system_autotools::install_dir(void) const
{
    /* A tree told not to install installs nothing, so there is no
     * directory for the cleaning targets to spare or to take -- and
     * asking install_prefix() anyway would hand them the default
     * prefix, a directory that never gets made. */
    if (_install == false)
        return "";

    return install_prefix();
}

std::string build_system_autotools::bootstrap_command(void) const
{
    /* Which of these two is asked first doesn't decide anything,
     * since the option that set either one cleared the other: at most
     * one of them is in force by the time anybody gets here. */
    if (_no_autoreconf == true)
        return "";

    /* Somebody who said what to run meant it, even for a tree this
     * would otherwise have decided needs nothing run at all. */
    if (_autoreconf.size() > 0)
        return _autoreconf;

    /* Nothing to make a configure out of means nothing to run, which
     * is what a release tarball looks like. */
    if (access((base() + "configure.ac").c_str(), R_OK) != 0
        && access((base() + "configure.in").c_str(), R_OK) != 0)
        return "";

    /* A tree that carries one of these carries it because the bare
     * autotools commands aren't enough for it: submodules to pull,
     * generated m4 to write, a libtoolize that has to happen in a
     * particular order.  Running it is the only way to find out what
     * it does, which is exactly why it's what the tree wants run. */
    if (access((base() + "autogen.sh").c_str(), X_OK) == 0)
        return "./autogen.sh";
    if (access((base() + "bootstrap").c_str(), X_OK) == 0)
        return "./bootstrap";

    /* automake's Makefile.in files and a tree's own m4 both have to be
     * regenerated along with the configure, and "autoreconf -i" is
     * the one command that runs the whole chain in the right order
     * and copies in the helper scripts it finds missing. */
    if (access((base() + "Makefile.am").c_str(), R_OK) == 0
        || access((base() + "aclocal.m4").c_str(), R_OK) == 0
        || access((base() + "m4").c_str(), R_OK) == 0)
        return "autoreconf -i";

    /* Which leaves a tree with a configure.ac and a hand-written
     * Makefile.in, where autoconf on its own is the whole job -- and
     * is also the only one of these that works when the machine has
     * no automake on it. */
    return "autoconf";
}

std::string build_system_autotools::with_env(const std::string& command) const
{
    auto out = std::string();

    for (const auto& env: _env) {
        /* The value is quoted and the name is not, which is the only
         * way round that works: a shell reads "NAME=VALUE cmd" as an
         * assignment in front of a command, and 'NAME=VALUE' quoted
         * whole stops being an assignment and becomes the name of a
         * program nobody has.  Left unquoted altogether -- which is
         * how this was first written -- an "--env CFLAGS=-O2 -g"
         * hands the shell a "-g" to run as a command of its own, and
         * the recipe dies with "-g: command not found" at build time
         * having been accepted without a murmur at configure time.
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

std::string build_system_autotools::configure_args(void) const
{
    /* One argument is one word, however many spaces are in it.  This
     * is the same rule makeopt_flags() follows and it's here for the
     * same reason: "CXXFLAGS=-g -O2" is a thing people write and
     * mean, and what the shell does with it unquoted is hand
     * configure a CXXFLAGS worth "-g" and then an "-O2" that
     * configure reads as a flag of its own.
     *
     * The value isn't taken apart, which is the thing that must not
     * happen: string_utils::quoted() leaves the value exactly as it
     * was written, so "$(abspath x)" still means what it says. */
    auto out = std::string();
    for (const auto& arg: _configure_args)
        out += " " + string_utils::quoted(arg);
    return out;
}

std::string build_system_autotools::configure_signature(void) const
{
    auto out = build_system::configure_signature();

    /* Which program makes the tree's configure isn't a CONFIGUREOPTS
     * when nobody wrote one: it's worked out by looking at the tree,
     * so a tree that grew a Makefile.am since the last configure is
     * bootstrapped by a different command than the recipe in the
     * Makefile says -- and nothing about a recipe changing is a
     * reason for make to run a rule.
     *
     * It's the only thing added here, and everything that isn't here
     * is left out on purpose.  In particular no path goes in: this
     * file is named after the tree's output directory and nothing
     * else, so a tree vendored inside a subproject writes one file
     * between the run at the top and the run inside it.  The two runs
     * describe the same directories from different places, so a path
     * in here would say something different each time and the two
     * runs would reconfigure the tree over and over, taking turns.
     * What the paths mean doesn't differ, only how they're spelled,
     * and it's the meaning this file is for. */
    auto bootstrap = bootstrap_command();
    if (bootstrap.size() > 0)
        out += "bootstrap " + bootstrap + "\n";

    return out;
}

/* Every file in the vendored tree, spelled relative to where
 * pconfigure ran.
 *
 * This is the guess that keeps a "make" in a tree that's already been
 * built from going back into it, and nothing more than that: the
 * build itself is the tree's own make, which is far better at working
 * out what to rebuild than anything guessed from out here.  So being
 * generous is free and being wrong is cheap, and the whole of the
 * cleverness is a walk.
 *
 * kconfig can do better than this because a kbuild tree says what it
 * reads -- it chases "source" and "include" lines, and then reads
 * back what the tree wrote down during its own build.  An autotools
 * tree says nothing of the kind before it has been configured, and
 * what it says afterwards is in the generated Makefiles, which are in
 * the build directory this walk is deliberately not looking at.  A
 * walk of the source is what's left.
 *
 * Directories whose names start with a '.' are skipped, which is what
 * keeps a submodule's .git out of the answer -- thousands of files
 * that change whenever anybody runs a git command, none of which is
 * an input to anything.  autom4te.cache goes too: it's autoconf's own
 * scratch, written inside the tree by the rule above this one, so
 * it's output wearing an input's clothes.
 *
 * Symlinked directories are not followed.  A tree with a symlink back
 * up to itself is a walk that never finishes, and a tree that has a
 * good reason for one -- a build that stages headers into a directory
 * of links, say -- has that reason during its build rather than
 * before it. */
static void walk_tree(const std::string& dir, std::vector<std::string>& out)
{
    auto handle = opendir(dir.c_str());
    if (handle == NULL)
        return;

    auto subdirs = std::vector<std::string>();

    struct dirent *entry;
    while ((entry = readdir(handle)) != NULL) {
        auto name = std::string(entry->d_name);
        if (name.size() == 0 || name[0] == '.')
            continue;
        if (name == "autom4te.cache")
            continue;

        auto path = dir + "/" + name;

        /* lstat rather than stat, so that a symlink is whatever it is
         * rather than whatever it points at. */
        struct stat buf;
        if (lstat(path.c_str(), &buf) != 0)
            continue;

        if (S_ISDIR(buf.st_mode) == true)
            subdirs.push_back(path);
        else if (S_ISREG(buf.st_mode) == true)
            out.push_back(path);
    }

    closedir(handle);

    /* Sorted, so that two runs over an unchanged tree write the same
     * Makefile: readdir hands things back in whatever order the
     * filesystem felt like, and a Makefile that shuffles its own
     * prerequisite lists is one nobody can diff. */
    std::sort(subdirs.begin(), subdirs.end());
    for (const auto& subdir: subdirs)
        walk_tree(subdir, out);
}

std::vector<makefile::target::ptr>
build_system_autotools::vendored_targets(
    const std::vector<build_system::ptr>& peers,
    /* Which project wrote these rules.  kconfig needs it because it
     * leaves files behind for the build to read back and has to say
     * which run wrote them; nothing here writes one, since the whole
     * of this build system's guess is in the Makefile itself. */
    const std::string&) const
{
    auto srcdir = source_dir();
    auto output = build_output();
    auto prefix = install_prefix();
    auto status = config_status();
    auto stamp = build_stamp();
    auto configure = srcdir + "/configure";

    /* What make prints while it's configuring the tree.  It's the
     * name of the build system that's doing it, since that's the
     * thing whose options went onto configure's command line. */
    auto label = name();
    for (auto& c: label)
        c = toupper(c);

    /********************************************************************
     * The tree's own configure                                         *
     ********************************************************************/
    /* The one thing here that gets written inside the vendored tree,
     * and the one thing that can't be arranged otherwise: autoconf
     * has no out-of-tree mode and writes "configure" beside the
     * "configure.ac" it was made from.  A tree that ships no
     * configure has already agreed to this -- its .gitignore says so
     * -- and it's a file the tree would have had if anybody had run
     * its own bootstrap by hand.
     *
     * Nothing removes it afterwards.  "make clean" takes the stamp
     * and "make distclean" takes this project's object directory,
     * and neither of those is a licence to reach into somebody else's
     * checkout and delete a file out of it. */
    auto bootstrap = bootstrap_command();

    auto configure_input = std::string();
    if (access((srcdir + "/configure.ac").c_str(), R_OK) == 0)
        configure_input = srcdir + "/configure.ac";
    else if (access((srcdir + "/configure.in").c_str(), R_OK) == 0)
        configure_input = srcdir + "/configure.in";

    if (bootstrap.size() == 0 && access(configure.c_str(), X_OK) != 0) {
        std::cerr << name() << ": there is no '" << configure << "' to run,"
                  << " and nothing here will make one\n"
                  << "  a tree with a configure.ac gets one made unless"
                  << " '--no-autoreconf' says otherwise,\n"
                  << "  and a tree that ships a configure needs it to be"
                  << " executable\n";
        abort();
    }

    auto out = std::vector<makefile::target::ptr>();

    /* The prerequisite the configure rule waits on.  When something
     * here knows how to make it that's this rule, handed over as
     * itself rather than as a second target with the same name, so
     * the two rules are one edge in make's graph. */
    auto configure_target = std::make_shared<makefile::target>(configure);

    if (bootstrap.size() > 0) {
        auto bootstrap_deps = std::vector<makefile::target::ptr>();
        if (configure_input.size() > 0)
            bootstrap_deps.push_back(
                std::make_shared<makefile::target>(configure_input));

        /* Through "$(wildcard)" rather than named outright, because
         * these were worked out by looking at the tree and the tree
         * moves: a submodule bump that deletes one of them leaves
         * make with a prerequisite nothing can build, at which point
         * it refuses to build anything at all -- not just this
         * subproject -- with an error whose way out ("make
         * reconfigure") it does not mention.  $(wildcard) is
         * re-expanded every run, so a file that has gone away stops
         * being named and one that comes back starts again. */
        bootstrap_deps.push_back(std::make_shared<makefile::target>(
            "$(wildcard " + srcdir + "/aclocal.m4 " + srcdir + "/*.m4 "
            + srcdir + "/m4/*.m4 " + srcdir + "/Makefile.am "
            + srcdir + "/*/Makefile.am " + srcdir + "/autogen.sh "
            + srcdir + "/bootstrap)"));

        configure_target = std::make_shared<makefile::target>(
            configure,
            "AUTORECONF\t" + srcdir,
            bootstrap_deps,
            std::vector<makefile::global_targets>{},
            std::vector<std::string>{
                /* Run from inside the tree, because that's where
                 * every one of these programs looks for its input and
                 * where all of them write their output.  One recipe
                 * line, since a "cd" in the line above would be over
                 * by the time this one started: make gives each line
                 * its own shell. */
                "cd " + srcdir + " && " + with_env(bootstrap),

                /* A bootstrap that wrote nothing is an error said
                 * here rather than left for configure to trip over,
                 * and it's also what makes the touch below safe: a
                 * plain touch of a target that isn't there creates an
                 * empty "configure" inside somebody else's checkout,
                 * which make would then call up to date forever and
                 * whoever owns the tree would find one day and
                 * wonder about.
                 *
                 * Both halves go through string_utils::echoed()
                 * rather than only the one with the Configfile's
                 * command in it.  The
                 * advice below is a constant and would survive being
                 * written any other way, but a recipe with two
                 * spellings of "print this sentence" in it is a
                 * recipe where the next line somebody adds is a coin
                 * toss -- and the half that is safe looks exactly
                 * like the half that isn't. */
                "test -f $@ || {"
                " echo " + string_utils::echoed(
                        name() + ": '" + bootstrap + "' in '" + srcdir
                        + "' wrote no '" + configure + "'")
                + ";"
                " echo " + string_utils::echoed(
                        "  a tree whose configure is made some other way"
                        " wants '--autoreconf CMD', and one that ships its"
                        " own wants '--no-autoreconf'")
                + ";"
                " exit 1; }",

                /* And the same hazard the config.status rule below
                 * ends with, in the shape it takes here.  autoreconf
                 * -- which is what this runs for most trees, and what
                 * almost every autogen.sh runs in turn -- rewrites
                 * configure only when configure.ac or aclocal.m4 is
                 * newer than it.  A Makefile.am is neither: editing
                 * one regenerates Makefile.in and leaves configure's
                 * mtime exactly as it was.  Since a Makefile.am is a
                 * prerequisite of this rule, that leaves the target
                 * older than what asked for it, and make runs the
                 * rule again on the next make, and the next, dragging
                 * a reconfigure and a sub-make along behind it with
                 * nothing that can ever settle it.  For a vendored
                 * binutils that is minutes of somebody's day, every
                 * make, forever. */
                "touch $@",
            },
            std::vector<std::string>{
                "The ./configure of the vendored build system in " + srcdir
                + ", which the tree doesn't ship and autoconf writes beside"
                " the configure.ac it's made from"
            });

        out.push_back(configure_target);
    }

    /********************************************************************
     * The configuration                                                *
     ********************************************************************/
    auto config_deps = std::vector<makefile::target::ptr>{configure_target};

    /* The templates configure fills in.  The tree's own generated
     * Makefiles have rules that re-run config.status when one of
     * these changes, but those rules only ever fire once make is
     * already inside the build directory -- and whether make goes in
     * there at all is exactly what this graph decides.  So they're
     * named here too, where they can be seen from outside. */
    config_deps.push_back(std::make_shared<makefile::target>(
        "$(wildcard " + srcdir + "/*.in " + srcdir + "/*/*.in "
        + srcdir + "/*/*/*.in)"));

    /* Everything the build waits for, the configuration waits for
     * too.  configure runs the compiler to find out what it can do --
     * that is most of what it does -- so a tree whose toolchain this
     * build produces needs that toolchain before it can be
     * configured, not just before it can be built.  Hanging these off
     * the build alone is what makes a fresh checkout take two passes
     * of make: the first one configures against a compiler that isn't
     * there yet and writes down the answers configure gives when it
     * can't run one. */
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
     * because the build already waits for the configuration, so one
     * file covers both. */
    config_deps.push_back(std::make_shared<makefile::target>(
        configureopts_file()));

    auto config_commands = std::vector<std::string>();

    /* What the old configuration installed goes before the new one is
     * written.  An install here has no rules behind it -- the recipe
     * that configures, builds and installs hangs off one stamp, and
     * the programs, libraries and headers that land in the prefix are
     * named by nothing -- so a file this tree installed once and
     * doesn't install any more goes on sitting in the directory the
     * rest of the build reads from, goes on satisfying the "test -e" a
     * SUBPROJECT_TARGETS gets, and goes on being found by anything
     * that looks one "bin" up.  Nothing else would ever remove it: the
     * stamp above it says the tree is installed, so no later make puts
     * the question again.  The build that follows this rule puts back
     * everything the current configuration does install, since the
     * stamp hangs off this rule.
     *
     * The build directory is deliberately left where it is, which is
     * the one place this differs from cmake's answer to the same
     * hazard: a cmake cache keeps a -D that has been deleted from the
     * Configfile and refuses a different generator outright, so the
     * only way to make it say what this run says is to not have it,
     * while re-running configure over an existing build directory is
     * the way autotools has always been told to change its mind.
     * Throwing it away would turn every edited CONFIGUREOPTS into a
     * rebuild of binutils from scratch for no reason anybody asked
     * for.
     *
     * Only when there is an install to take, and only when the prefix
     * is this tree's own: see private_prefix() for why a directory
     * somebody wrote down is not this rule's to empty.  A tree built
     * with --no-install has no prefix at all -- the directory this
     * would name is one nothing in this configuration ever creates --
     * so removing it would be a line of recipe claiming the build
     * installs somewhere when it doesn't. */
    if (_install == true && private_prefix() == true)
        config_commands.push_back("rm -fr " + prefix);

    config_commands.push_back("mkdir -p " + output);

    /* Those two, and the "cd" below, and the "$(MAKE) -C" in the
     * build rule, name their directories as bare words.  It is the
     * same answer the rest of pconfigure gives and the same reason:
     * a directory whose name holds a quote, a space or a shell
     * metacharacter does not build, quoting these lines would not
     * change that -- a subproject's paths arrive as an expansion of
     * the make variable standing for its directory, and quotes round
     * the reference quote nothing inside it -- and it is not
     * path_prefix::rewrite() that stops the quotes, which is the
     * thing that looks like the reason and isn't.  See
     * makefile::path_prefix and "Odd Behavior" in
     * doc/pconfigure.tex. */

    /* Out of tree, always.  configure works out where its sources are
     * from the path it was run as, which is why this is an absolute
     * path rather than a "../../sub/configure": a relative one would
     * make the tree's own srcdir relative too, and then every
     * generated Makefile in every subdirectory would be pointing at a
     * different number of "..".  pconfigure only ever works in
     * relative paths, so make gets to do the conversion, at the point
     * where it knows what directory it's in.
     *
     * The prefix goes the same way and for a harder reason: autotools
     * bakes it into what it builds, from libtool's rpaths to the
     * paths a program looks its own data up under, and a relative one
     * would be baked in relative to wherever the tree happened to be
     * built. */
    config_commands.push_back(
        "cd " + output + " && "
        + with_env("$(abspath " + srcdir + ")/configure"
                   /* Quoted through string_utils::quoted(), the way
                    * configure_args() quotes everything else and for
                    * the same reason: this is the one argument on the
                    * line whose value somebody wrote in a Configfile,
                    * so it's the one most likely to name a directory
                    * with a space in it -- and an argument joined with
                    * an '=' that gets split in half is a configure that
                    * installs somewhere nobody asked for and says
                    * nothing about it.
                    *
                    * Through the helper rather than with a pair of
                    * quotes written here, which is what this used to
                    * be.  Hand-written quotes are right until the
                    * value has a quote of its own in it: a prefix
                    * under a directory called "it's" closed the
                    * argument early and left the shell reading the
                    * rest of the recipe for a quote that never came,
                    * so a legal --prefix became a syntax error at
                    * build time having been accepted at configure
                    * time.  quoted() is where the "'\''" that
                    * handles a quote is written down once. */
                   " " + string_utils::quoted("--prefix=$(abspath "
                                              + prefix + ")")
                   + configure_args()));

    /* A configure that decided nothing had changed could leave
     * config.status exactly as it was, mtime included, which would
     * leave it older than whatever asked for it and run all of this
     * again on every make. */
    config_commands.push_back("touch $@");

    auto config_target = std::make_shared<makefile::target>(
        status,
        label + "\t" + srcdir,
        config_deps,
        std::vector<makefile::global_targets>{},
        config_commands,
        std::vector<std::string>{
            "The configuration of the vendored build system in " + srcdir
        });

    out.push_back(config_target);

    /********************************************************************
     * The build                                                        *
     ********************************************************************/
    auto files = std::vector<std::string>();
    walk_tree(srcdir, files);
    std::sort(files.begin(), files.end());

    auto build_deps = std::vector<makefile::target::ptr>{config_target};
    if (files.size() > 0)
        build_deps.push_back(std::make_shared<makefile::target>(
            "$(wildcard " + string_utils::join(files, " ") + ")"));

    /* Said again here rather than left to the configuration this
     * build already waits for, so that the rule that names the thing
     * being built is the rule that says what it was built out of. */
    for (const auto& depend: _depends)
        build_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    /* make runs in the build directory rather than in the tree, which
     * is the whole of what an out-of-tree build is: the Makefile
     * configure wrote is in there, and it knows where its sources
     * are.
     *
     * One sub-make per target rather than one sub-make with a list of
     * goals, in the order the targets were asked for.  A "make -j"
     * handed several goals is allowed to run them at the same time,
     * and "all install" run at the same time is an install of a tree
     * that is still being built.  The stamp still gets written last,
     * so it says every target that was asked for succeeded. */
    auto submake = with_env("$(MAKE) --no-print-directory -C " + output
                          + makeopt_flags());

    auto build_commands = std::vector<std::string>();
    if (_make_targets.size() == 0)
        build_commands.push_back(submake);

    /* The target is quoted, which is what everything else a
     * CONFIGUREOPTS wrote gets on its way into a recipe and is here
     * for the same reason: one option is one target.  That is what the
     * option says it is -- a tree that wants two of them writes
     * --target twice, and they are asked for one at a time on purpose
     * -- so the spaces in one of them are characters of a name rather
     * than a list this is allowed to split on.  Left raw, a semicolon
     * in a target ends the recipe's command and hands the shell
     * whatever came after it to run as a program of its own: a
     * Configfile read without a murmur at configure time and a build
     * that runs something nobody asked for.
     *
     * The paths around it stay as they are, here and everywhere else
     * in this file: every recipe line goes through
     * path_prefix::rewrite() on its way into the Makefile, which is
     * what lets a subproject's rules name the same files from above
     * and from inside.  A quote is one of the characters it reads as
     * the end of one word and the start of the next, so a value
     * wrapped in quotes is still rewritten -- which is what makes the
     * quotes around the prefix above free. */
    for (const auto& make_target: _make_targets)
        build_commands.push_back(
            submake + " " + string_utils::quoted(make_target));

    /* The install is part of building the tree rather than part of
     * "make install", because what is vendored is vendored so that
     * the rest of this build can use it -- and the rest of this build
     * happens during "make".  A build system that put this on "make
     * install" instead would produce a "make" that looked like it
     * worked and a build one step further on that couldn't find the
     * tool. */
    if (_install == true)
        build_commands.push_back(submake + " install");

    build_commands.push_back("mkdir -p " + output_dir());
    build_commands.push_back("date > $@");

    auto build_target = std::make_shared<makefile::target>(
        stamp,
        "MAKE\t" + srcdir,
        build_deps,
        /* ALL is what makes a plain "make" build the tree.  CLEAN
         * takes the stamp and the install, and not the build
         * directory: what the tree built is the tree's, and throwing
         * it away would mean a "make clean" costs an hour of somebody's
         * day rather than a second.  What removing the stamp does buy
         * is that the next make goes back into the tree and lets the
         * tree decide.  The build directory goes on a "make distclean",
         * which is the one that says the object directory as a whole is
         * no longer wanted. */
        std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        },
        build_commands,
        std::vector<std::string>{
            "The vendored build system in " + srcdir + ", which is run"
            " whenever one of the files it could read has changed"
        });

    /* The install goes with the stamp, which costs a clean nothing it
     * wasn't already costing: the stamp is what the install hangs off,
     * so a clean is already a re-entry into the tree and an install
     * again.  What it buys is that the one file a configuration
     * stopped installing has a way out that doesn't need anybody to
     * know the file is there -- and, for whoever is staring at a
     * prefix full of something they can't account for, that "make
     * clean" is an answer.
     *
     * The same two conditions the reconfigure above is under, and for
     * the same reasons: nothing to take when the tree was told not to
     * install, and not this rule's to take when the directory is one a
     * Configfile named and a peer may be installing into.  See
     * private_prefix(). */
    if (_install == true && private_prefix() == true)
        build_target = build_target->with_clean_extra(prefix);

    out.push_back(build_target);

    return out;
}
