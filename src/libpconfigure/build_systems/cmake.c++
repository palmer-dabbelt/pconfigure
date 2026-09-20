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

#include "cmake.h++"
#include "../file_utils.h++"
#include "../string_utils.h++"
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <iostream>

build_system_cmake::build_system_cmake(const std::string& name)
: build_system(name),
  _generator("Unix Makefiles"),
  _build_type(),
  _defines(),
  _configure_args(),
  _prefix(),
  _install(true),
  _make_targets(),
  _jobs(),
  _env(),
  _depends(),
  _config_depends(),
  _configure_lines(),
  _build_lines()
{
}

build_system* build_system_cmake::clone(void) const
{
    /* Everything a CONFIGUREOPTS puts in here is a string, a bool or
     * a vector of strings, so the copy constructor has already made
     * the deep copy this promises to make.  It stays that way as long
     * as nobody puts a pointer to something shared in the class. */
    return new build_system_cmake(*this);
}

bool build_system_cmake::can_build(const std::string& base) const
{
    /* A CMakeLists.txt is the whole of what cmake is told to look
     * for, so it's the whole of what this looks for: "cmake -S DIR"
     * reads exactly that file and nothing else decides whether a
     * directory is a cmake project.
     *
     * Nothing here tries to rule out a tree that also has a
     * configure.ac in it, and that's deliberate.  Such a tree really
     * can be built both ways -- Verilator is one -- so refusing it
     * would be claiming to know which of two right answers was meant,
     * which is a thing only the BUILD_SYSTEMS order can say. */
    return access((base + "CMakeLists.txt").c_str(), R_OK) == 0;
}

namespace {
    /* TRUE when a string ends with another one, which is how a
     * generator name is recognized. */
    bool ends_with(const std::string& in, const std::string& tail)
    {
        if (in.size() < tail.size())
            return false;
        return in.compare(in.size() - tail.size(), tail.size(), tail) == 0;
    }

    /* One argument of text that is being written down rather than run,
     * quoted so that nothing between here and the file gets to change
     * a character of it.
     *
     * string_utils::quoted() keeps the shell out of it and
     * string_utils::unexpanded() keeps make's variables out of it,
     * which between them are string_utils::echoed() and used to be
     * the whole list.
     * They aren't, and that is why this is not simply a call to
     * echoed().  Every recipe line written here goes through
     * path_prefix::rewrite() on its way into the Makefile, which finds
     * anything that looks like a path into one of the projects of this
     * run and puts the variable that stands for that project's
     * directory in front of what's left.  That is exactly right for
     * the paths in a command -- it is the whole of what lets a
     * subproject's Makefile be included by its parent's and still name
     * the same files -- and exactly wrong here, where the text is an
     * argument to a printf rather than a path to anything.  A
     * '--env FOO=child/x' written in the subproject "child" would
     * otherwise be recorded as "child/x" by a make run at the top and
     * as "x" by a make run in the subproject, so one configuration
     * would write down two different things and the rule that exists
     * to notice an option moving would notice make moving instead.
     *
     * What stops it is that every directory rewrite() can match ends
     * in a '/', so a '/' that no directory name runs up to is a '/' it
     * has nothing to match on.  Closing the quotes around each piece
     * between the slashes buys that for nothing: the shell glues
     * "'child'/'x'" back into the single word "child/x", and what the
     * Makefile holds has no "child/" anywhere in it for the rewriting
     * to find. */
    std::string recorded(const std::string& in)
    {
        auto text = string_utils::unexpanded(in);
        auto out = std::string();

        size_t start = 0;
        while (true) {
            auto slash = text.find('/', start);
            if (slash == std::string::npos)
                return out + string_utils::quoted(text.substr(start));

            out += string_utils::quoted(text.substr(start, slash - start))
                 + "/";
            start = slash + 1;
        }
    }

    /* A signature taken apart into the lines it was built out of.  A
     * recipe is a line of shell, so text with newlines in it has to
     * reach the file as one argument per line rather than as itself. */
    std::vector<std::string> signature_lines(const std::string& in)
    {
        auto out = std::vector<std::string>();

        size_t start = 0;
        while (start < in.size()) {
            auto end = in.find('\n', start);
            if (end == std::string::npos)
                end = in.size();
            out.push_back(in.substr(start, end - start));
            start = end + 1;
        }

        return out;
    }

    /* Every directory under a vendored tree, written as one glob
     * apiece for make to expand.
     *
     * This is a guess and deliberately a generous one.  The build
     * itself is somebody else's build system, which is the thing that
     * decides what to recompile -- all this is for is giving a "make"
     * in a tree that's already built a reason not to recurse at all.
     * Nothing here tries to work out what a CMakeLists.txt means: the
     * only program that knows which files a cmake project reads is
     * cmake, and it only knows after it has run.
     *
     * A directory rather than a list of files, because a cmake tree
     * names its sources inside its CMakeLists.txt and reading them
     * back out is the one thing we've just said we won't do.  It also
     * keeps this cheap where it matters: LLVM is a hundred and forty
     * thousand files in four thousand directories, and one word per
     * directory is a prerequisite list make can hold an opinion about
     * while one word per file is a megabyte of Makefile.  What it
     * costs is precision -- a directory's own timestamp moves when
     * something is added to it or taken out of it, and the files
     * inside it are named by the glob -- which for a vendored tree
     * that nothing but git ever writes to is precision nobody misses.
     *
     * The "$(wildcard)" that wraps the result is the other half of
     * the answer, and it's the half that matters on a submodule bump:
     * these paths were true when pconfigure looked, a bump deletes
     * some of them, and a prerequisite that is named outright and has
     * gone away stops make building anything at all -- not just this
     * subproject -- with an error that never mentions the way out.
     *
     * None of these is quoted, and there is nowhere to put the
     * quotes: what they become is a prerequisite list rather than a
     * command.  make splits that on spaces, "$(wildcard)" splits its
     * own argument on spaces again before it globs anything, and no
     * shell ever reads the line -- so a quote written here would be a
     * character in a file name rather than a quote.  A vendored
     * directory whose name has a space in it therefore arrives as two
     * words that name nothing the tree has and drops out of the list,
     * and what that costs is a re-entry into the tree that should
     * have happened: the guess got shorter, which is the one way this
     * guess is allowed to be wrong.  It is not the way the paths in
     * the recipes below are allowed to be wrong, which is why the
     * difference is written down here rather than left looking like
     * an oversight. */
    void chase(const std::string& dir,
               const std::string& skip,
               bool root,
               std::vector<std::string>& out)
    {
        /* A tree named as the directory pconfigure itself ran in has
         * no walk that makes sense: everything this project builds is
         * under there too, including the output directory this walk
         * is about to be a prerequisite of. */
        if (dir.size() == 0)
            return;

        auto handle = opendir(dir.c_str());
        if (handle == NULL)
            return;

        auto subdirs = std::vector<std::string>();
        auto configured = false;

        while (true) {
            auto entry = readdir(handle);
            if (entry == NULL)
                break;

            auto name = std::string(entry->d_name);

            /* "." and ".." would walk this tree forever, and the rest
             * of what starts with a dot is version control and
             * editor scratch: a build that re-entered the tree every
             * time git wrote an index would re-enter it constantly.
             * $(wildcard) doesn't match them either, so leaving them
             * out here says the same thing the globs say. */
            if (name.size() == 0 || name[0] == '.')
                continue;

            auto path = dir + name;

            /* A directory reached through a symlink is not followed.
             * A tree with a link to one of its own parents in it
             * would otherwise not be walked so much as fallen into. */
            struct stat info;
            if (lstat(path.c_str(), &info) != 0)
                continue;

            if (S_ISDIR(info.st_mode) == true) {
                subdirs.push_back(path + "/");
                continue;
            }

            if (name == "CMakeCache.txt")
                configured = true;
        }

        closedir(handle);

        /* A directory with a cache in it is a cmake build directory,
         * which is output rather than source: walking it would make
         * the tree's own product a prerequisite of building the tree,
         * and make would then have a reason to rebuild after every
         * build, forever.  The tree this was pointed at is exempt,
         * since somebody who configured it in place is still asking
         * for it to be built and the alternative is walking nothing
         * at all. */
        if (configured == true && root == false)
            return;

        /* And the same again for the directory this build system is
         * about to write into, which is only under the tree if
         * somebody put the object directory there. */
        if (dir == skip)
            return;

        out.push_back(dir + "*");

        for (const auto& subdir: subdirs)
            chase(subdir, skip, false, out);
    }
}

bool build_system_cmake::make_generator(void) const
{
    return ends_with(_generator, "Unix Makefiles");
}

bool build_system_cmake::run_by_make(void) const
{
    return make_generator();
}

std::string build_system_cmake::with_env(const std::string& command) const
{
    auto out = std::string();

    for (const auto& env: _env) {
        /* The value is quoted and the name is not, which is the only
         * way round that works: a shell reads "NAME=VALUE cmd" as an
         * assignment in front of a command, and 'NAME=VALUE' quoted
         * whole stops being an assignment and becomes the name of a
         * program nobody has.  Left unquoted altogether an
         * "--env CXXFLAGS=-g -O2" hands the shell an "-O2" to run as a
         * command once cmake has finished, which is a recipe that dies
         * at build time having been accepted without a murmur at
         * configure time.
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

std::string build_system_cmake::install_prefix(void) const
{
    /* Inside this build system's own output directory, which is the
     * prefix that can't surprise anybody: it's made by the build that
     * fills it, it's thrown away by the "make distclean" that throws
     * the rest of the build away, it's a place "make cache-clean" is
     * told not to look, and a plain "make" writing into it is a plain
     * "make" writing into its own object directory. */
    if (private_prefix() == true)
        return output_dir() + "/prefix";

    /* Everywhere else the question is the same question every build
     * system here asks about an install prefix, so it is asked in one
     * place and answered one way: see build_system::install_dir() for
     * what the cleaning targets do with this directory, and
     * build_system::checked_install_dir() for what a prefix is not
     * allowed to name and why. */
    return checked_install_dir("--prefix", _prefix);
}

std::string build_system_cmake::install_dir(void) const
{
    /* A tree told not to install installs nothing, so there is no
     * directory for the cleaning targets to spare or to take -- and
     * asking install_prefix() anyway would hand them the default
     * prefix, a directory that never gets made. */
    if (_install == false)
        return "";

    return install_prefix();
}

std::string build_system_cmake::build_dir(void) const
{
    return _install == true ? install_prefix() : cmake_build_dir();
}

std::string build_system_cmake::build_command(const std::string& target) const
{
    /* The target is quoted whichever of the two builds below it lands
     * in, which is what everything else a CONFIGUREOPTS wrote gets
     * here and for the same reason: one option is one target.  That
     * is what the option says it is -- a tree that wants two of them
     * writes --target twice, and they are asked for one at a time on
     * purpose -- so the spaces and the semicolons in one of them are
     * characters of a name rather than a list this is allowed to
     * split on.  Left raw, a semicolon in a target ends the recipe's
     * command and hands the shell whatever came after it to run as a
     * program of its own: a Configfile accepted without a murmur at
     * configure time and a build that dies saying a word nobody wrote
     * is not a command.  The --configure-arg the configure rule pastes
     * in raw is the one option deliberately not treated this way, and
     * it says why where it is written.
     *
     * The build directory is not quoted, and neither is any other
     * path in here.  That is the pconfigure-wide answer to a path
     * with a quote in its name rather than a decision taken here, and
     * it is worth saying which answer it is, because the plausible
     * one is wrong: path_prefix::rewrite() is NOT what stops the
     * quotes.  That rewrite reads a quote as the end of a word, so
     * "cd 'sub/obj/build'" is rewritten to
     * "cd '$(pconfigure_subdir_sub)obj/build'" exactly as the bare
     * spelling is -- which is why recorded() above has to close the
     * quotes around every slash to stop it, and would have nothing to
     * do if a pair of quotes round the whole thing were enough.
     *
     * What quoting here would not buy is the thing anybody would
     * reach for it for.  A subproject's paths arrive as an expansion
     * of the variable above, so quotes round the reference quote
     * nothing that is inside it: '$(pconfigure_subdir_it_s)obj/build'
     * expands to 'it's/obj/build', the same unbalanced quote one step
     * later, and the variable cannot hold an escaped path because the
     * same variable names make prerequisites.  So a directory with an
     * apostrophe in it does not build whatever this line does, and
     * quoting only the recipes that can be quoted would leave that
     * true while looking as though it weren't.  The whole of it is
     * written up on makefile::path_prefix and under "Odd Behavior" in
     * doc/pconfigure.tex. */

    /* A recursive $(MAKE) rather than "cmake --build", for the one
     * thing the abstraction throws away: that token is what makes GNU
     * make hand this build its jobserver, so a "make -j8" up here is
     * eight jobs in total rather than eight plus however many the
     * tree decides to start.  It's also the only shape a MAKEOPS
     * means anything in. */
    if (make_generator() == true) {
        auto out = "$(MAKE) --no-print-directory -C " + cmake_build_dir()
                 + makeopt_flags();
        if (target.size() > 0)
            out += " " + string_utils::quoted(target);
        return with_env(out);
    }

    /* And for everything else, cmake's own way of asking for a build
     * without knowing what it generated.  No leading '+' on this
     * line: a build that isn't a make can't join the jobserver
     * anyway, and the '+' would also mean running it under a
     * "make -n" that was asked to print what a build would do rather
     * than to do it. */
    auto out = "cmake --build " + cmake_build_dir();
    if (target.size() > 0)
        out += " --target " + string_utils::quoted(target);
    /* The one piece of a CONFIGUREOPTS that goes in raw and stays
     * that way: --jobs is digits or it never got past
     * take_configureopt(), and there is nothing a string of digits
     * can do to a command line. */
    if (_jobs.size() > 0)
        out += " --parallel " + _jobs;
    return with_env(out);
}

std::string build_system_cmake::configureopt_help(void) const
{
    return "  '--generator NAME' picks the build system cmake writes\n"
           "  '--build-type NAME' sets CMAKE_BUILD_TYPE\n"
           "  '--define VAR=VALUE' sets a cache variable\n"
           "  '--prefix DIR' says where the tree installs to\n"
           "  '--configure-arg ARG' puts one more argument on cmake's"
           " command line\n"
           "  '--target NAME' asks the tree for a target rather than for"
           " its default\n"
           "  '--jobs N' says how many jobs a build that runs its own"
           " may use\n"
           "  '--install' and '--no-install' say whether building the tree"
           " installs it\n"
           "  '--env NAME=VALUE' puts a variable in the environment it runs"
           " in\n"
           "  '--depend PATH' waits for something else before configuring"
           " and building\n"
           "  '--depend-config PATH' waits for something else before"
           " configuring\n";
}

build_system::answers build_system_cmake::already_answered(void) const
{
    auto out = answers();

    /* A cache variable arrives as "-DNAME=VALUE" on cmake's own
     * command line, as the "NAME=VALUE" a --define or a MAKEOPS
     * writes, or with the ":TYPE" a "-D" is allowed to carry.  The
     * "-D" may also be a word of its own with the assignment in the
     * next one, which is why every word of an option gets asked
     * rather than the first.
     *
     * "-U" is the same list read backwards and it is the reason this
     * has to be a list at all: it deletes a cache variable, it is
     * processed after the "-D" that set it, and a
     * '--configure-arg -UCMAKE_INSTALL_PREFIX' therefore takes the
     * prefix this build system wrote back off -- leaving cmake's own
     * default, which is "/usr/local", installed into by a plain
     * "make".  Nothing about the word says it is a destination; what
     * says so is the name inside it, which is the name this refuses.
     *
     * "--" is here for cmake's own "--install-prefix", which is the
     * same statement spelled as an option rather than as a cache
     * variable. */
    out.decorations = std::vector<std::string>{"", "-D", "-U", "--"};

    /* cmake abbreviates nothing: its options are spelled out, and a
     * name that is a prefix of a cache variable's name is a different
     * cache variable.  Nor does it read a '-' in a name as a '_'. */
    out.abbreviated = false;
    out.dashed = false;

    out.prefix_option = "--prefix DIR";

    /* A relative value of one of the GNUInstallDirs variables is
     * joined to CMAKE_INSTALL_PREFIX by the install() that reads it,
     * so it cannot name anything outside the prefix and there is no
     * reason to refuse it: '--define CMAKE_INSTALL_LIBDIR=lib' is a
     * tree told to use the layout this project reads, which is a
     * thing somebody has every right to say and which --prefix cannot
     * say for them.
     *
     * The special cases in GNUInstallDirs, where a relative value is
     * joined to something other than the prefix, are all for a prefix
     * of "/", "/usr" or "/opt/..." -- and every one of those is a
     * prefix checked_install_dir() has already refused, since none of
     * them is inside this project's object directory. */
    out.relative_subdirectories = true;

    /* Where the whole install goes.
     *
     * CMAKE_STAGING_PREFIX is the one of these a list of
     * GNUInstallDirs plus CMAKE_INSTALL_PREFIX misses, and it is the
     * worst one to miss: it is documented as where to install when
     * the real prefix has to stay pristine, so every install() lands
     * under it instead, the prefix this build system wrote is left in
     * the cache saying something that isn't true, and the directory a
     * SUBPROJECT_TARGETS is named from stays empty.
     *
     * DESTDIR is neither cmake's nor this build system's: it is read
     * out of the environment while the install is running and pasted
     * onto the front of whatever the others came to, which is why it
     * is in the same list and why it is the one of these a MAKEOPS or
     * an --env can say.
     *
     * Written out rather than matched by shape.  "Anything that
     * starts with CMAKE_INSTALL_" would take CMAKE_INSTALL_RPATH and
     * CMAKE_INSTALL_MESSAGE with it, which say nothing about where
     * anything lands; "anything ending in DIR" would take
     * CMAKE_INSTALL_NAME_DIR, which is a macOS link-time thing.
     *
     * What is not here, deliberately: a file the vendored tree ships.
     * A CMakeLists.txt with an absolute install() DESTINATION, a
     * toolchain file that sets a staging prefix, a CMakePresets.json
     * -- each of those is the tree saying where it installs, in the
     * tree, and pconfigure reads none of them.  This list is about a
     * second answer written in a Configfile, where there is a line to
     * quote back and a person to tell. */
    for (const auto& variable: {"CMAKE_INSTALL_PREFIX",
                                "CMAKE_STAGING_PREFIX", "DESTDIR"})
        out.destinations.push_back(
            {variable, "says where the tree installs to"});

    /* cmake's own option for the first of those, which takes its
     * directory in the word after it and so is caught on this one.
     * The name it sets is in the sentence, since the word a
     * Configfile wrote is what a diagnostic has to quote back. */
    out.destinations.push_back(
        {"install-prefix",
         "says where the tree installs to, being cmake's own spelling"
         " of CMAKE_INSTALL_PREFIX"});

    /* And where one kind of file goes inside the prefix: the
     * GNUInstallDirs variables, which is the module a project that
     * installs anything in the GNU layout includes.  Every one of
     * them is read under the prefix when it is relative and out from
     * under it when it isn't, which is what relative_subdirectories
     * above is about. */
    for (const auto& variable: {
            "CMAKE_INSTALL_BINDIR", "CMAKE_INSTALL_SBINDIR",
            "CMAKE_INSTALL_LIBEXECDIR", "CMAKE_INSTALL_SYSCONFDIR",
            "CMAKE_INSTALL_SHAREDSTATEDIR", "CMAKE_INSTALL_LOCALSTATEDIR",
            "CMAKE_INSTALL_RUNSTATEDIR", "CMAKE_INSTALL_LIBDIR",
            "CMAKE_INSTALL_INCLUDEDIR", "CMAKE_INSTALL_OLDINCLUDEDIR",
            "CMAKE_INSTALL_DATAROOTDIR", "CMAKE_INSTALL_DATADIR",
            "CMAKE_INSTALL_INFODIR", "CMAKE_INSTALL_LOCALEDIR",
            "CMAKE_INSTALL_MANDIR", "CMAKE_INSTALL_DOCDIR"})
        out.subdirectories.push_back(
            {variable, "says where part of the install goes"});

    /* And the two directories this build system named itself, one
     * word each.  cmake keeps the last "-B" it is handed, and a
     * --configure-arg is pasted on after everything written here, so
     * '--configure-arg -B /tmp/elsewhere' configures without a murmur
     * and leaves a whole cmake build tree in /tmp that nothing in
     * this project ever removes -- the configure rule's "rm -fr" and
     * "make distclean" both name the directory cmake didn't use.  "-S"
     * is one word over and builds a tree no SUBPROJECTS named.
     *
     * CMAKE_HOME_DIRECTORY, which is the cache variable for the
     * second of those, is not here because it needs nothing from us:
     * cmake refuses it outright when it disagrees with the source
     * directory it was handed, and says so. */
    out.directories.push_back({"-B", "says where the tree builds"});
    out.directories.push_back({"-S", "says which tree gets configured"});

    return out;
}

void build_system_cmake::take_makeopt(const std::string& opt)
{
    refuse_second_answer("MAKEOPS", opt);
}

void build_system_cmake::take_configureopt(const std::string& opt)
{
    /* The flags that take no value are compared against the whole
     * line, since option_value() has nothing to hand back for one and
     * answers "this isn't my flag" instead.  Tidied first because
     * what arrives here is the rest of the Configfile line, spaces
     * and all. */
    auto whole = string_utils::clean_white(opt);

    auto generator = option_value(opt, "--generator");
    if (generator.size() > 0) {
        _generator = generator;

        /* Both lists: the generator decides what cmake writes, which
         * is a configure, and it decides how what cmake wrote gets
         * run, which is a build. */
        _configure_lines.push_back(opt);
        _build_lines.push_back(opt);
        return;
    }

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
                      << " '--define LLVM_TARGETS_TO_BUILD=RISCV'\n";
            abort();
        }

        /* Where the tree installs is the one thing a cache variable
         * may not say here: this build system puts the same path into
         * the cache, into the install and into whatever a
         * SUBPROJECT_TARGETS names, so a second answer wins in the
         * cache and loses everywhere else -- a build that installs
         * somewhere nothing goes looking.
         *
         * Every spelling of it rather than CMAKE_INSTALL_PREFIX
         * alone, which is what this used to ask: a
         * CMAKE_INSTALL_BINDIR with an absolute value sailed through
         * and moved the programs out from under the prefix. */
        refuse_second_answer("--define", define);

        _defines.push_back(define);
        _configure_lines.push_back(opt);
        return;
    }

    auto prefix = option_value(opt, "--prefix");
    if (prefix.size() > 0) {
        /* Nothing is asked about it here: where a prefix may point is
         * one question with one answer for every vendored build
         * system, and it needs the project this was bound to, which a
         * CONFIGUREOPTS written under a BUILD_SYSTEMS hasn't got.
         * install_prefix() asks. */
        _prefix = prefix;
        _configure_lines.push_back(opt);
        return;
    }

    auto configure_arg = option_value(opt, "--configure-arg");
    if (configure_arg.size() > 0) {
        /* This one reaches cmake's command line raw and after
         * everything this build system wrote, so a "-D" in here is
         * the last word on any variable it names -- which made it the
         * widest way round the --define check above, and is why it
         * gets the same one. */
        refuse_second_answer("--configure-arg", configure_arg);

        _configure_args.push_back(configure_arg);
        _configure_lines.push_back(opt);
        return;
    }

    auto make_target = option_value(opt, "--target");
    if (make_target.size() > 0) {
        _make_targets.push_back(make_target);
        _build_lines.push_back(opt);
        return;
    }

    auto jobs = option_value(opt, "--jobs");
    if (jobs.size() > 0) {
        for (const auto& c: jobs) {
            /* Through an unsigned char, which is the only thing
             * isdigit() is defined for: it is specified over the
             * values of an unsigned char plus EOF, and a plain 'char'
             * is signed on every machine this builds on, so a byte
             * above 0x7f arrives as a negative number and indexes the
             * table the implementation keeps in front of it.  What
             * comes back on the two libcs this is built against
             * happens to be "not a digit", which is the right answer
             * -- so this cast buys no behaviour anybody can see here
             * and is written for the next libc rather than for these
             * two.  It is the same cast cargo's --jobs makes, and the
             * reason to write it here is that one of the two making
             * it and the other not is how a rule stops being a rule. */
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
        /* What an --env is allowed to look like is one question with
         * one answer for every build system here, so it is asked in
         * one place: see build_system::checked_env(). */
        checked_env("--env", env, "PATH=/opt/gnubin:$(PATH)");

        /* And the fourth spelling of where the tree installs, which
         * is the environment -- where DESTDIR is read from in the
         * first place, by the install script cmake generates.  It was
         * refused as a --define, as a --configure-arg and as a
         * MAKEOPS and taken here, which is worse than never having
         * refused it: three closed doors and an open one read as a
         * closed door, and what came through this one was every file
         * the tree installs, written under whatever it pointed at, on
         * a plain "make". */
        refuse_second_answer("--env", env);

        /* Both lists, since the configure and the build are two
         * programs run in the same environment and either of them
         * reading a different one is a tree configured for a machine
         * it wasn't built for. */
        _env.push_back(env);
        _configure_lines.push_back(opt);
        _build_lines.push_back(opt);
        return;
    }

    /* The longer flag is looked for first so that none of this rests
     * on "--depend" refusing to match "--depend-config".  It does
     * refuse, but only because option_value() insists the character
     * after a flag be a space or an '=', which is a thing to know
     * rather than a thing to lean on. */
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

std::string build_system_cmake::configure_signature(void) const
{
    /* The configure-side options, one per line, in the order they
     * were given and character for character.  This is
     * build_system::configure_signature() with the build-side lines
     * held back rather than anything cleverer: the order is part of
     * the answer, since a later "-D" of a name is the one cmake
     * keeps, and the raw lines are enough even though they get turned
     * into settings with defaults behind them, because a default can
     * only be moved off by an option and every option is here.
     *
     * Nothing derived goes in.  What the options are turned into is
     * paths -- the build directory, the default prefix -- and a path
     * is spelled differently depending on which project's run wrote
     * it, so a derived line would have a pconfigure at the top of the
     * tree and a pconfigure inside the subproject each undoing the
     * other's file on every configure. */
    auto out = std::string();
    for (const auto& line: _configure_lines)
        out += line + "\n";

    return out;
}

std::string build_system_cmake::build_signature(void) const
{
    auto out = std::string();
    for (const auto& line: _build_lines)
        out += line + "\n";

    /* A MAKEOPS isn't a CONFIGUREOPTS, but it goes on the command
     * line of the sub-make that builds the tree, so changing one has
     * changed how the tree gets built just as surely as a --target
     * would.  All of them, with none of build_system's care about
     * which arrived as an option, because this build system has no
     * option that says one: there is only MAKEOPS, so there is
     * nothing to say twice. */
    for (const auto& opt: makeopts())
        out += "MAKEOPS " + opt + "\n";

    return out;
}

std::vector<makefile::target::ptr>
build_system_cmake::vendored_targets(
    const std::vector<build_system::ptr>& peers,
    const std::string& project_base __attribute__((unused))) const
{
    auto srcdir = source_dir();
    auto build = cmake_build_dir();
    auto cache = cache_file();
    auto stamp = build_stamp();

    /* What make prints while it's configuring the tree.  It's the
     * name of the build system that's doing it, since that's the
     * thing whose options the tree was configured with. */
    auto label = name();
    for (auto& c: label)
        c = toupper(c);

    /* A MAKEOPS written above the --generator that made it
     * meaningless gets here rather than being refused where it stood:
     * when it arrived nothing yet knew what the generator would be,
     * and run_by_make() had to answer something.  Refusing it loudly
     * now is the only alternative to building the tree with the
     * variable quietly dropped, which is a build that is wrong in
     * exactly the way the variable was meant to prevent. */
    if (make_generator() == false && makeopts().size() > 0) {
        std::cerr << name() << ": MAKEOPS '" << makeopts()[0] << "' has no"
                  << " make to go on the command line of: the '" << _generator
                  << "' generator doesn't build by running one\n"
                  << "  a variable this would have set is a cache variable"
                  << " here, so write '--define NAME=VALUE'\n";
        abort();
    }

    /* And the other way around: a build that is a sub-make takes its
     * parallelism from the make that ran it, and a "-j" of its own
     * is how a "make -j8" turns into sixty-four compilers.  Told
     * rather than ignored, since a number that silently did nothing
     * would be read by the next person as the reason the build is
     * slow. */
    if (make_generator() == true && _jobs.size() > 0) {
        std::cerr << name() << ": '--jobs " << _jobs << "' has no build of"
                  << " its own to run: the '" << _generator << "' generator"
                  << " builds by running make, which takes its parallelism"
                  << " from the make that ran it\n"
                  << "  run 'make -j" << _jobs << "' instead, or ask for a"
                  << " generator that runs its own build\n";
        abort();
    }

    /********************************************************************
     * The configuration                                                *
     ********************************************************************/
    /* Everything this run has to say about how the tree is built into
     * one command line, since cmake is asked once and remembers.
     *
     * The prefix reaches it absolutely, which is make's job rather
     * than ours: cmake writes a prefix into its cache and into the
     * things it builds, and a relative one would mean whichever
     * directory somebody happened to be standing in.  Everything else
     * stays relative, so the rewriting that lets this Makefile be
     * included by a parent's has something to rewrite. */
    auto configure = with_env(
        "cmake -S " + srcdir + " -B " + build
        + " -G " + string_utils::quoted(_generator)
        + " " + string_utils::quoted("-DCMAKE_INSTALL_PREFIX=$(abspath "
                       + install_prefix() + ")"));

    if (_build_type.size() > 0)
        configure += " "
                   + string_utils::quoted("-DCMAKE_BUILD_TYPE="
                                        + _build_type);

    for (const auto& define: _defines)
        configure += " " + string_utils::quoted("-D" + define);

    /* Not quoted, unlike everything above it: a --configure-arg is
     * written the way it will appear on the command line, so a person
     * who needs two arguments writes two words and a person who needs
     * one word with a space in it writes the quotes themselves.
     * There is no other way to spell "--toolchain x.cmake" as one
     * option. */
    for (const auto& arg: _configure_args)
        configure += " " + arg;

    auto config_deps = std::vector<makefile::target::ptr>();
    for (const auto& depend: _config_depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend-config", depend, peers)));

    /* Everything the build waits for, the configuration waits for
     * too.  cmake runs the compiler while it is deciding what the
     * tree can do -- that is what the whole of its configure step is
     * -- so a tree whose toolchain this build produces needs that
     * toolchain before it can be configured, not just before it can
     * be built.  Hanging these off the build alone is what makes a
     * fresh checkout take two passes of make: the first one writes
     * down the answers cmake gives when it can't run a compiler. */
    for (const auto& depend: _depends)
        config_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    /* What this run was told, which has to be a prerequisite because
     * nothing else here is: every other file this rule could name is
     * one the tree or the project already had, so a build
     * reconfigured with different options would find all of them
     * exactly as it left them and do nothing.  pconfigure writes this
     * one, and rewrites it only when it says something different than
     * it did last time. */
    config_deps.push_back(std::make_shared<makefile::target>(
        configureopts_file()));

    /* Configuring is starting over.  A cmake cache keeps a -D that has
     * been deleted from the Configfile and refuses to be reconfigured
     * with a different generator at all, so the only way to make a
     * build directory say what this run says is to not have the old
     * one.  It costs a rebuild, which is why nothing but the options
     * and the --depends gets to trigger it: an edit to a
     * CMakeLists.txt is picked up by the build re-entering the tree,
     * where cmake regenerates itself. */
    auto config_commands = std::vector<std::string>{"rm -fr " + build};

    /* And what the old configuration installed goes with it, for the
     * same reason: a file the tree installed once and doesn't build
     * any more goes on sitting in the directory the rest of this build
     * reads from, goes on satisfying the "test -e" a SUBPROJECT_TARGETS
     * gets, and goes on being found by anything that looks one "bin"
     * up.  The build that follows puts back everything the current
     * configuration does install, since the stamp hangs off this rule.
     *
     * Only when there is an install to take, and only when the prefix
     * is this tree's own.  A --prefix is written down by somebody who
     * wanted several trees in one directory, and a peer's install is
     * not this tree's to remove -- especially not here, where the
     * peer's stamp would still say it is built and so nothing would
     * install it again.  And a tree built with --no-install has no
     * prefix at all: the directory this would name is one nothing in
     * this configuration ever creates, so removing it is a line of
     * recipe that says the build installs somewhere when it doesn't.
     * A prefix left behind by a configuration that used to install is
     * inside output_dir(), which "make distclean" takes whole; chasing
     * it from here would mean a build that was told not to install
     * removing a directory anyway. */
    if (_install == true && private_prefix() == true)
        config_commands.push_back("rm -fr " + install_prefix());

    config_commands.push_back("mkdir -p " + build);
    config_commands.push_back(configure);

    /* A cmake that decided nothing had changed would leave the cache
     * exactly as it was, mtime included, which would leave it older
     * than whatever asked for it and run this again on every make.  It
     * can't happen after the rm above, and it costs nothing to be
     * sure. */
    config_commands.push_back("touch $@");

    auto config_target = std::make_shared<makefile::target>(
        cache,
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
     * the generated build system's business, and it's better at it
     * than any guess made out here would be.  All these are for is
     * giving make a reason not to recurse at all. */
    auto dirs = std::vector<std::string>();
    chase(base(), output_dir() + "/", true, dirs);
    std::sort(dirs.begin(), dirs.end());

    /* The build-side options, written into a file by make out of what
     * this recipe says they are.
     *
     * The name it hangs off is never a file, so make asks this on
     * every build.  The recipe answers by writing the options into a
     * temporary and putting it in place only when it says something
     * the file didn't already say, which is what keeps a build that is
     * already done from being redone: a prerequisite whose rule ran
     * and whose mtime didn't move is a prerequisite nothing is newer
     * than.
     *
     * Each option goes through recorded(), which is what keeps the
     * three things that rewrite a recipe on its way to the shell away
     * from text that is being written down rather than run: make's
     * variable expansion, the shell's own idea of what a semicolon or
     * a space is for, and the path rewriting that lets an included
     * Makefile name the same files from two directories.  A tree that
     * was told nothing gets an empty file rather than no file, since
     * "no file" is a thing make would try to build again on every
     * single build. */
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
        auto lines = signature_lines(build_signature());
        if (lines.size() == 0) {
            write_opts = ": > $@.tmp";
        } else {
            write_opts = "printf '%s\\n'";
            for (const auto& line: lines)
                write_opts += " " + recorded(line);
            write_opts += " > $@.tmp";
        }
    }

    auto opts_target = std::make_shared<makefile::target>(
        buildopts_file(),
        std::string(),
        std::vector<makefile::target::ptr>{opts_force},
        std::vector<makefile::global_targets>{},
        std::vector<std::string>{
            /* Nothing has made the object directory on a fresh
             * checkout: this rule is the first thing in it to run. */
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
            "$(wildcard " + string_utils::join(dirs, " ") + ")"));

    /* Said again here rather than left to the configuration this
     * build already waits for, so that the rule that names the thing
     * being built is the rule that says what it was built out of. */
    for (const auto& depend: _depends)
        build_deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    /* The other half of what this run was told, for the same reason
     * the configure rule waits on the first half: a tree asked for a
     * target it wasn't asked for last time has to be asked again, and
     * nothing else in this rule would have changed.
     *
     * Written by a rule of its own rather than by pconfigure -- see
     * the header, which is where the ordering that makes that the only
     * safe spelling is written out. */
    build_deps.push_back(opts_target);

    /* One build per target rather than one build with a list of
     * goals, in the order the targets were asked for.  A build handed
     * several goals is allowed to run them at the same time, and a
     * tree whose targets have to be asked for separately is asking
     * for them in an order for a reason.  The stamp still gets
     * written last, so it says every target that was asked for
     * succeeded -- which is all it can say, since it can't say which
     * targets those were: re-running pconfigure rewrites this recipe,
     * but nothing about a recipe changing is a reason for make to run
     * it, so a tree that's already built stays built.  That is what
     * build-opts is a prerequisite for. */
    auto build_commands = std::vector<std::string>();
    if (_make_targets.size() == 0)
        build_commands.push_back(build_command(""));
    for (const auto& make_target: _make_targets)
        build_commands.push_back(build_command(make_target));

    /* Installing is part of building, and last: a vendored tool tree
     * is vendored so the rest of this build can run the tool, and the
     * rest of this build happens during "make". */
    if (_install == true)
        build_commands.push_back(build_command("install"));

    build_commands.push_back("mkdir -p " + output_dir());
    build_commands.push_back("date > $@");

    auto build_target = std::make_shared<makefile::target>(
        stamp,
        "BUILD\t" + srcdir,
        build_deps,
        /* ALL is what makes a plain "make" build the tree.  CLEAN
         * takes the stamp and the install, and not the build
         * directory: a "make clean" that threw that away would be an
         * hour of LLVM to get back something the Makefile never had an
         * opinion about, so what it does here is make the next make
         * re-enter the tree and let the tree decide.  The build
         * directory goes on a "make distclean", which is the one that
         * says the object directory as a whole is no longer wanted. */
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

    /* The install goes with the stamp, which costs a clean nothing it
     * wasn't already costing: the stamp is what the install hangs off,
     * so a clean is already a re-entry into the tree and an install
     * again.  What it buys is that the one file a configuration
     * stopped installing has a way out that doesn't need anybody to
     * know this file exists.
     *
     * Only the prefix this build system picked for itself, and only
     * when the tree installs into it.  A --prefix names a directory
     * somebody wrote down and several trees may be installing into,
     * and "rm -fr" on that is not a promise a "make clean" gets to
     * make -- it isn't even this tree's directory to have an opinion
     * about.  A tree built with --no-install doesn't have the other
     * one either: what it produces is in the build directory, which a
     * clean deliberately leaves alone, and the prefix is a path this
     * configuration never writes to. */
    if (_install == true && private_prefix() == true)
        build_target = build_target->with_clean_extra(install_prefix());

    return std::vector<makefile::target::ptr>{
        config_target, opts_force, opts_target, build_target
    };
}
