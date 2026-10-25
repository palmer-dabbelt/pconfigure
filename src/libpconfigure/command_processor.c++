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

#include "command_processor.h++"
#include "commands.h++"
#include "file_utils.h++"
#include "languages/gen_proc.h++"
#include "languages/implicit_h.h++"
#include "languages/phony.h++"
#include "string_utils.h++"
#include <pinclude.h++>
#include <cctype>
#include <cstdlib>
#include <iostream>
#include <unistd.h>

command_processor::command_processor(const std::string& base,
                                     const context::ptr& defaults)
    : _stack(),
      _opts_target(NULL),
      _stale_opts_target(NULL),
      _stale_opts_closed_by(NULL),
      _build_systems(),
      _vendored(),
      _configure_target(NULL),
      _test_suites(),
      _autoreconfigure(false),
      _autoreconfigure_cmd(NULL),
      _read_a_subproject(false),
      _default_test_suite(),
      _default_test_suite_cmd(NULL),
      _abrt_is_fail(false),
      _abrt_is_fail_cmd(NULL),
      _test_suite_target(NULL),
      _given_version_command(false),
      _given_help_command(false),
      _given_srcpath(false),
      _srcpath(base.size() == 0 ? "." : base.substr(0, base.size() - 1)),
      _base(base),
      _root(std::make_shared<context>(base))
{
    /* A subproject is its own project, with its own languages and its
     * own directories, but it does get built and installed as part of
     * whoever pulled it in -- so it starts out installing to the same
     * place, and using the same tools.  Anything its own Configfile
     * says about either still wins. */
    if (defaults != NULL) {
        _root->prefix = defaults->prefix;
        _root->phc = defaults->phc;
        _root->verbose = defaults->verbose;
        _root->debug = defaults->debug;
        _root->cross_compile = defaults->cross_compile;

        /* Who works out the dependencies is a property of the build
         * rather than of one Configfile.  A subproject's Makefile is
         * included by the one make was actually run on, so both
         * halves land in the same make either way -- and a tree whose
         * parent asked for its dependencies to be worked out by the
         * build is a tree whose sources nobody is going to configure
         * again by hand.
         *
         * Said on the root context too, so that it reaches a
         * subproject of a subproject.  A tree with its own
         * AUTORECONFIGURE line still wins, the way it does with a
         * PREFIX. */
        _autoreconfigure = defaults->autoreconfigure;
        _root->autoreconfigure = defaults->autoreconfigure;

        /* How loudly a project wants to be told about the things
         * below is a property of the build rather than of one
         * Configfile, so a subproject is as strict as whoever pulled
         * it in until it says otherwise. */
        _root->strictness = defaults->strictness;
    }

    /* Every project can build a pconfigure subproject without being
     * told how: there's an implicit "BUILD_SYSTEMS += pconfigure" at
     * the bottom of all of them, and it's first in the list so that a
     * directory with a Configfile in it is read rather than handed to
     * somebody else's build system. */
    _build_systems.push_back(build_system::create("pconfigure"));

    _stack.push(_root);
    auto tos = _stack.top();
    tos->languages->add(std::make_shared<language_gen_proc>(
        std::vector<std::string>{},
        std::vector<std::string>{}
    ));
    tos->languages->add(std::make_shared<language_implicit_h>(
        std::vector<std::string>{},
        std::vector<std::string>{}
    ));
    tos->languages->add(std::make_shared<language_phony>(
        std::vector<std::string>{},
        std::vector<std::string>{}
    ));
}

void command_processor::set_opts_target(const opts_target::ptr& target)
{
    _opts_target = target;
    _stale_opts_target = NULL;
    _stale_opts_closed_by = NULL;
}

void command_processor::check_opts_target(const command::ptr& cmd)
{
    if (_stale_opts_target == NULL)
        return;

    _stack.top()->strictness.complain(
        strict_since::v0_13(),
        cmd->debug(),
        std::to_string(cmd->type()) + " lands on the '"
        + _stale_opts_target->cmd->data() + "' that "
        + std::to_string(_stale_opts_closed_by->type())
        + " already closed, on "
        + std::to_string(_stale_opts_closed_by->debug()),
        "move it above that line, or open the target again with the "
        + std::to_string(_stale_opts_target->cmd->type())
        + " it belongs to");
}

/* Which commands name a file or a target rather than describing one.
 * A value with a space in it means two different things to these two
 * groups: a COMPILEOPTS is a command line and is meant to have spaces
 * in it, while a SOURCES is one path and a space in it is somebody
 * expecting a list. */
static bool names_a_path(const command_type& type)
{
    switch (type) {
    case command_type::BINARIES:
    case command_type::BOOTSTRAP:
    case command_type::CONFIG_DEPS:
    case command_type::DEPTESTS:
    case command_type::ENTITLEMENTS:
    case command_type::GENERATE:
    case command_type::HDRDIR:
    case command_type::HEADERS:
    case command_type::HEADERSRC:
    case command_type::LIBDIR:
    case command_type::LIBEXECS:
    case command_type::LIBRARIES:
    case command_type::PREFIX:
    case command_type::SOURCES:
    case command_type::SRCDIR:
    case command_type::SRCPATH:
    case command_type::SUBPROJECTS:
    case command_type::SUBPROJECT_TARGETS:
    case command_type::TESTDEPS:
    case command_type::TESTEXECS:
    case command_type::TESTS:
    case command_type::TESTSRC:
    case command_type::TGENERATE:
        return true;

    case command_type::ABRT_IS_FAIL:
    case command_type::AUTODEPS:
    case command_type::AUTORECONFIGURE:
    case command_type::BUILD_SYSTEMS:
    case command_type::COMPAT:
    case command_type::COMPILEOPTS:
    case command_type::COMPILER:
    case command_type::CONFIG:
    case command_type::CONFIGUREOPTS:
    case command_type::CROSS_COMPILE:
    case command_type::DEBUG:
    case command_type::DEFAULT_TEST_SUITE:
    case command_type::DEPLIBS:
    case command_type::FRAMEWORKS:
    case command_type::HELP:
    case command_type::INCLUDE_TEST_SUITES:
    case command_type::LANGUAGES:
    case command_type::LINKER:
    case command_type::LINKOPTS:
    case command_type::MAKEOPS:
    case command_type::PHC:
    case command_type::PHONY:
    case command_type::STRICT:
    case command_type::TEST_SUITES:
    case command_type::VERBOSE:
    case command_type::VERSION:
        return false;
    }

    return false;
}

/* Which commands can be given nothing by backticks that printed
 * nothing.  The lists of options can: each line adds its words to
 * the list, and adding none is what "pkg-config --cflags" asks for
 * when a library needs no flags.  CROSS_COMPILE can, because set to
 * nothing is how a target takes back a cross toolchain it inherited.
 *
 * Nothing else can.  Everything else names something -- a target, a
 * file, a directory, a language, a library -- and a name that is
 * nothing is not a name: an empty LIBDIR makes every library path
 * absolute, and an empty BINARIES would leave the SOURCES under it
 * on whatever binary came before.  Those are the same lines that are
 * refused when the value is left off by hand. */
static bool can_be_given_nothing(const command_type& type)
{
    switch (type) {
    case command_type::COMPILEOPTS:
    case command_type::CONFIGUREOPTS:
    case command_type::CROSS_COMPILE:
    case command_type::LINKOPTS:
    case command_type::MAKEOPS:
        return true;

    case command_type::ABRT_IS_FAIL:
    case command_type::AUTODEPS:
    case command_type::AUTORECONFIGURE:
    case command_type::BINARIES:
    case command_type::BOOTSTRAP:
    case command_type::BUILD_SYSTEMS:
    case command_type::COMPAT:
    case command_type::COMPILER:
    case command_type::CONFIG:
    case command_type::CONFIG_DEPS:
    case command_type::DEBUG:
    case command_type::DEFAULT_TEST_SUITE:
    case command_type::DEPLIBS:
    case command_type::DEPTESTS:
    case command_type::ENTITLEMENTS:
    case command_type::FRAMEWORKS:
    case command_type::GENERATE:
    case command_type::HDRDIR:
    case command_type::HEADERS:
    case command_type::HEADERSRC:
    case command_type::HELP:
    case command_type::INCLUDE_TEST_SUITES:
    case command_type::LANGUAGES:
    case command_type::LIBDIR:
    case command_type::LIBEXECS:
    case command_type::LIBRARIES:
    case command_type::LINKER:
    case command_type::PHC:
    case command_type::PHONY:
    case command_type::PREFIX:
    case command_type::SOURCES:
    case command_type::SRCDIR:
    case command_type::SRCPATH:
    case command_type::STRICT:
    case command_type::SUBPROJECTS:
    case command_type::SUBPROJECT_TARGETS:
    case command_type::TESTDEPS:
    case command_type::TESTEXECS:
    case command_type::TESTS:
    case command_type::TESTSRC:
    case command_type::TEST_SUITES:
    case command_type::TGENERATE:
    case command_type::VERBOSE:
    case command_type::VERSION:
        return false;
    }

    return false;
}

/* Which commands take a name in brackets.  The name says which test
 * suite a test joins, so the lines that write a test are the ones
 * with somewhere to put one -- everything else names a thing there is
 * only ever one of. */
static bool takes_a_qualifier(const command_type& type)
{
    switch (type) {
    case command_type::TESTS:
    case command_type::TESTSRC:
        return true;

    case command_type::ABRT_IS_FAIL:
    case command_type::AUTODEPS:
    case command_type::AUTORECONFIGURE:
    case command_type::BINARIES:
    case command_type::BOOTSTRAP:
    case command_type::BUILD_SYSTEMS:
    case command_type::COMPAT:
    case command_type::COMPILEOPTS:
    case command_type::COMPILER:
    case command_type::CONFIG:
    case command_type::CONFIG_DEPS:
    case command_type::CONFIGUREOPTS:
    case command_type::CROSS_COMPILE:
    case command_type::DEBUG:
    case command_type::DEFAULT_TEST_SUITE:
    case command_type::DEPLIBS:
    case command_type::DEPTESTS:
    case command_type::ENTITLEMENTS:
    case command_type::FRAMEWORKS:
    case command_type::GENERATE:
    case command_type::HDRDIR:
    case command_type::HEADERS:
    case command_type::HEADERSRC:
    case command_type::HELP:
    case command_type::INCLUDE_TEST_SUITES:
    case command_type::LANGUAGES:
    case command_type::LIBDIR:
    case command_type::LIBEXECS:
    case command_type::LIBRARIES:
    case command_type::LINKER:
    case command_type::LINKOPTS:
    case command_type::MAKEOPS:
    case command_type::PHC:
    case command_type::PHONY:
    case command_type::PREFIX:
    case command_type::SOURCES:
    case command_type::SRCDIR:
    case command_type::SRCPATH:
    case command_type::STRICT:
    case command_type::SUBPROJECTS:
    case command_type::SUBPROJECT_TARGETS:
    case command_type::TESTDEPS:
    case command_type::TESTEXECS:
    case command_type::TEST_SUITES:
    case command_type::TGENERATE:
    case command_type::VERBOSE:
    case command_type::VERSION:
        return false;
    }

    return false;
}

/* TRUE when a string is a name a test suite could have.  The name is
 * what the suite's make targets are called, so a character make reads
 * as something other than itself makes a rule nobody can ask for --
 * and one that make may well have taken apart into several rules on
 * the way in. */
static bool names_a_suite(const std::string& str)
{
    if (str.size() == 0)
        return false;

    for (const auto& c: str)
        if (isalnum(c) == 0 && c != '-' && c != '_' && c != '.')
            return false;

    return true;
}

/* Which of the ways of leaving the project this path is, or "" for
 * one that stays inside it.  What comes back is the clause a
 * diagnostic puts after naming the command, since the three spellings
 * are wrong for three different reasons and a message that named none
 * of them leaves whoever reads it working out which one they wrote.
 *
 * This is build_system::checked_project_path()'s question, asked of
 * the commands rather than of a vendored tree's options, and the
 * reasoning is written down there.  The part worth having twice is
 * why it is asked of the text exactly as the Configfile wrote it,
 * before this project's own base goes on the front: resolving first
 * turns a subproject's "../elsewhere" into the parent's "elsewhere",
 * which climbs out of nothing and sails through -- so one line would
 * be legal read from the top and refused read from inside the
 * subproject, and the reading that accepts it is the one where the
 * line names a directory belonging to somebody else.
 *
 * It is not a call to that function, and the difference is the one
 * question it asks that this one must not.  A space in a value that
 * names a path is a strict::complain() in process() below, because
 * these commands are a great deal older than the rule and strict.h++
 * is where this project writes down what it does about that.  Asking
 * it again here would promote a documented warning to a refusal on
 * the way past, which is a change to a rule nobody made -- and
 * checked_project_path() says as much in its own comment, where it
 * names "LIBDIR = my dir" as the case that belongs up here.  This is
 * the other end of that sentence. */
static std::string leaves_the_project(const std::string& written)
{
    auto relative = file_utils::normalize_path(written);

    /* An absolute path names one directory however the line is read,
     * which is exactly what stops it being this project's: the
     * project moves between one run and the next and the path
     * doesn't. */
    if (relative.size() > 0 && relative[0] == '/')
        return "it's an absolute path, which names the same directory"
               " however this project is read -- so it isn't a directory"
               " of this project's";

    /* Both spellings of climbing, because the bare ".." is the one a
     * check written as "starts with '../'" lets through: there is no
     * trailing slash on it for that to match.  It is also the worst
     * of them -- "../out" names a directory beside the project, while
     * ".." names the directory the project was checked out into,
     * which is everything. */
    if (relative == ".." || relative.compare(0, 3, "../") == 0)
        return "it climbs out of the project, and a path that climbs out"
               " has no prefix of this project's to hang off -- so it"
               " names one directory read from above and a different one"
               " read from inside";

    /* And a path that isn't a path yet.  Everything decided here is
     * decided from the text as written, and what make expands is not
     * text anything out here can read: "$(HOME)/lib" goes past as one
     * harmless-looking component and is an absolute path by the time
     * a recipe runs, with the quotes around it belonging to the shell
     * rather than to make. */
    if (written.find('$') != std::string::npos)
        return "it's a make expansion rather than a path, so what it"
               " comes to is settled by make -- long after the last place"
               " that could have said whether it was inside this project";

    return "";
}

/* Refuses "cmd" outright when its value has one of
 * build_system::unsafe_metacharacter()'s characters in it -- a
 * character a shell, or make's own recipe line, reads as an
 * instruction of its own wherever it sits, with no space needed on
 * either side to do it.  "command_name" is how the diagnostic names
 * the command that carried the value, so one wording serves LIBDIR,
 * SOURCES, PREFIX and everything else that calls this.
 *
 * This is the one refusal on this list with no compatibility question
 * behind it.  A bare ".." is something an old project might be
 * relying on without knowing it, which is what strict.h++'s warnings
 * are for; nothing was ever relying on a semicolon in a LIBDIR,
 * because nothing before this asked whether there was one.  So every
 * call site gets a hard abort, whether or not that site's own
 * "leaves the project" check below is a warning or a refusal.
 *
 * Asked once, here, of every command that reaches build_system's
 * checked_project_path() through a different door -- LIBDIR, SOURCES,
 * PREFIX, ENTITLEMENTS, GENERATE, TESTDEPS, DEPTESTS, SUBPROJECTS --
 * rather than copied out at each of them, for the same reason
 * unsafe_metacharacter() itself is shared: one list of characters,
 * asked one way, rather than as many as there are call sites.
 *
 * FRAMEWORKS also asks this, even though a framework name never
 * reaches checked_project_path() -- it reaches a linker command line
 * exactly the way an ENTITLEMENTS path reaches codesign's, which is
 * the same hazard by a different door. */
static void refuse_unsafe_metacharacter(const command::ptr& cmd,
                                        const std::string& command_name)
{
    auto found = build_system::unsafe_metacharacter(cmd->data());
    if (found.size() == 0)
        return;

    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: " << command_name << " has a '" << found
              << "' in it: '" << cmd->data() << "'\n"
              << "  " << command_name << " reaches a Makefile recipe as"
              << " text, and a shell -- which is what runs that recipe --"
              << " reads a '" << found << "' as an instruction of its own"
              << " wherever it appears, with no space needed on either"
              << " side: what this names is not the one word it looks"
              << " like, it is that word followed by whatever the"
              << " character tells a shell to do next\n"
              << "  write " << command_name << " without one\n";
    abort();
}

/* Refuses a BINARIES, LIBRARIES, LIBEXECS, TESTEXECS or HEADERS whose
 * own name leaves the project.
 *
 * A target's name is a path as much as a SOURCES is, and a more
 * dangerous one.  It is pasted onto bin/ (or lib/, libexec/,
 * testexec/, include/) to say where the output lands, onto obj/ to
 * say where it is linked, and onto "$(DESTDIR)$PREFIX/bin" and its
 * siblings to say where "make install" puts it -- so "BINARIES +=
 * ../../evil" links a program into a directory beside the checkout,
 * installs it beside the prefix rather than in it, and hands both of
 * those paths to "make clean" and "make uninstall" to remove.  A
 * HEADERS with nothing under it is read from include/ and installed
 * the same way, so "../../x.h" reads somebody else's file and
 * installs it outside the include directory.
 *
 * Every other command that names a path was already asked this, and
 * the target's own name was simply never on the list.  A refusal
 * rather than a strict warning for the same reason SOURCES is
 * refused: an output written outside the project is not something
 * a working build could have been relying on.
 *
 * A name with a directory in it is still fine -- "BINARIES +=
 * tools/run" is a program in bin/tools -- because the question is
 * where the name ends up, which leaves_the_project() answers from
 * the normalized path, not whether it has a slash in it. */
static void refuse_target_leaving_project(const command::ptr& cmd)
{
    auto leaves = leaves_the_project(cmd->data());
    if (leaves.size() == 0)
        return;

    /* The example is the kind of name this command takes, so that what
     * the message suggests is something that could be pasted back in. */
    std::string example = "tools/main";
    if (cmd->type() == command_type::LIBRARIES)
        example = "libmain.so";
    if (cmd->type() == command_type::HEADERS)
        example = "main/api.h";

    auto command_name = std::to_string(cmd->type());
    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: " << command_name << " names a target outside"
              << " this project: " << leaves << "\n"
              << "  a target's name is where it is built and where 'make"
              << " install' puts it, so this one would be written, installed"
              << " and later removed somewhere nothing in this build owns\n"
              << "  name it from inside the project, like '"
              << command_name << " += " << example << "'\n";
    abort();
}

/* Refuses "cmd", a SUBPROJECTS or a BOOTSTRAP naming the tree at
 * "path", when that tree sits somewhere this build's "make distclean"
 * would either remove or reach out of: inside the object directory
 * "obj_dir", or -- once symlinks are resolved -- outside the project
 * or inside that object directory after all.
 *
 * Both commands come here because both end in the same place.  A
 * BOOTSTRAP is read as an ordinary subproject once its two extra
 * checks are done, so its tree is built and distcleaned exactly the
 * way a SUBPROJECTS one is, and a tree that would be lost or reached
 * through by one would be by the other.  The vendored pconfigure is,
 * if anything, the worse one to lose: without it the next "make" has
 * nothing to build a pconfigure with.  Asking once, here, keeps the
 * two from drifting apart the way they had, with BOOTSTRAP asking
 * only the questions its own case happened to remember. */
static void refuse_unsafe_subproject_location(const command::ptr& cmd,
                                              const std::string& path,
                                              const std::string& obj_dir)
{
    auto command_name = std::to_string(cmd->type());

    /* The caller has already refused a path that climbs out of the
     * project, and this is the other end of the same sentence.
     * pconfigure owns every byte under an object directory -- that is what lets
     * an install prefix be in there, and it is what "make
     * distclean" acts on: the recipe is an "rm -rf" of the
     * object directory and nothing finer, because everything
     * under it is output this build knows how to make again.  A
     * tree checked out in there is not, so the first distclean
     * after somebody writes this line takes the checkout with
     * it, and what was lost is whatever had not been pushed.
     *
     * The object directory this asks about is the one in force
     * where the line was written, which for a SUBPROJECTS inside
     * a subproject is that subproject's own rather than the one
     * at the top of the run.  No command moves it: an object
     * directory is a project's directory with "obj" on the end,
     * and what changes from one context to the next is which
     * project that is. */
    auto obj = file_utils::normalize_path(obj_dir);
    if (file_utils::inside(
            file_utils::normalize_path(path), obj) == true) {
        std::cerr << command_name << " can't name a directory inside an"
                  << " object directory: '"
                  << std::to_string(cmd->debug())
                  << "'\n"
                  << "  '" << obj << "' is where this build writes, and"
                  << " 'make distclean' removes it whole -- so a tree"
                  << " checked out in there is one distclean away from"
                  << " being gone, and nothing about the recipe says"
                  << " so\n"
                  << "  check the tree out somewhere this build doesn't"
                  << " write, beside the Configfile that names it; where"
                  << " it builds to is pconfigure's to pick\n";
        abort();
    }

    /* And both of those questions asked a second time, of the
     * directory rather than of the name, because a symlink is
     * where the two stop agreeing.  "rm -rf sub/obj" follows a
     * symlinked "sub" -- rm declines to walk through a symlink
     * only when it is the last thing on the path -- so a "sub"
     * pointing anywhere at all is a distclean that reaches there,
     * and a "vendor" pointing into the object directory is the
     * checkout this build removes whole.  Both read as an
     * ordinary name, which is what a symlink is for.
     *
     * Asking lexically is still the rule about what a line means,
     * and this leaves that alone.  A path that climbs out or
     * lands in the object directory is refused on its text, by the
     * caller and just above, before any of this runs, so nothing refused there becomes
     * legal here: all this can do is refuse something more.  What
     * it asks is a different question -- not "what does this line
     * name", which the text settles, but "what is the recipe
     * about to remove", which only the filesystem knows.  And it
     * keeps the property the lexical rule exists to protect,
     * because both sides are resolved: the answer is the same
     * whether pconfigure ran in this project or in one above it,
     * which is exactly what resolving only one side would have
     * thrown away.
     *
     * A symlink that stays inside the tree is left alone, which
     * is why this asks where the link goes rather than refusing a
     * link outright.  Linking a vendored tree into place from
     * somewhere else in the same checkout is a real thing to do
     * and there is nothing wrong with it: what the "rm -rf"
     * reaches is inside the project either way.
     *
     * A path that doesn't resolve is left to whoever reads the
     * Configfile that isn't there.  Saying nothing here costs
     * nothing, since a directory that doesn't exist is one no
     * symlink can have pointed out of the tree. */
    auto real_sub = file_utils::real_directory(path);
    auto real_root = file_utils::real_directory(".");
    auto real_obj = file_utils::real_directory(obj);

    if (real_sub.size() > 0 && real_root.size() > 0
        && file_utils::inside(real_sub, real_root) == false) {
        std::cerr << command_name << " can't reach outside the project: '"
                  << std::to_string(cmd->debug())
                  << "'\n"
                  << "  '" << path << "' resolves to '" << real_sub
                  << "', which is outside '" << real_root << "'\n"
                  << "  'make distclean' is an 'rm -rf' of this"
                  << " subproject's output directories, and rm walks"
                  << " through a symlink it meets partway along a path"
                  << " -- so the recipe removes directories out there"
                  << " rather than in here\n"
                  << "  check the tree out beside the Configfile that"
                  << " names it, or point the link somewhere inside"
                  << " this project\n";
        abort();
    }

    if (real_sub.size() > 0 && real_obj.size() > 0
        && file_utils::inside(real_sub, real_obj) == true) {
        std::cerr << command_name << " can't name a directory inside an"
                  << " object directory: '"
                  << std::to_string(cmd->debug())
                  << "'\n"
                  << "  '" << path << "' resolves to '" << real_sub
                  << "', which is inside '" << real_obj << "'\n"
                  << "  '" << obj << "' is where this build writes, and"
                  << " 'make distclean' removes it whole -- so a tree"
                  << " checked out in there is one distclean away from"
                  << " being gone, and nothing about the recipe says"
                  << " so\n"
                  << "  check the tree out somewhere this build doesn't"
                  << " write, beside the Configfile that names it; where"
                  << " it builds to is pconfigure's to pick\n";
        abort();
    }
}

/* Which commands name a target or a source that one of the language
 * backends writes a rule for, under the name exactly as it was
 * written: a BINARIES becomes "bin/<name>" on the left of a rule, a
 * SOURCES becomes the prerequisite of an object whose own name is
 * built out of it, and both are pasted bare into the recipes that
 * copy, compile and link them.
 *
 * Narrower than names_a_path() on purpose.  A SUBPROJECTS or a
 * SUBPROJECT_TARGETS reaches the Makefile through a vendored build
 * system, which quotes what it writes, and a SUBPROJECT_TARGETS with
 * an apostrophe in it is something that tree really does build.  A
 * PREFIX, a LIBDIR and the rest of the directories go through
 * checked_project_path(), which asks its own questions of them.
 * These are the ones nothing asked. */
static bool names_a_make_target(const command_type& type)
{
    switch (type) {
    case command_type::BINARIES:
    case command_type::HEADERS:
    case command_type::HEADERSRC:
    case command_type::LIBEXECS:
    case command_type::LIBRARIES:
    case command_type::SOURCES:
    case command_type::TESTS:
    case command_type::TESTSRC:
        return true;

    default:
        return false;
    }

    return false;
}

/* Why "c" can't be in the name of a target or a source, or "" when it
 * can.  These are the characters that make, or the shell running one
 * of make's recipes, reads as syntax of its own rather than as part of
 * a name -- each one checked by building a BINARIES with it in the
 * middle, and each one either stopping make, stopping the shell or
 * quietly building something other than what was named.  There are two
 * halves to the list, and a name only has to fall foul of one.
 *
 * make's half is the rule line: a '#' starts a comment, a ':' ends the
 * targets, an '=' turns the line into an assignment, a ';' starts a
 * recipe, a '|' starts the order-only prerequisites, a '$' starts an
 * expansion, and a '(' is an archive member.  The shell's half is the
 * recipes the name is pasted into bare: quotes open strings, a ';', a
 * '&', a '|', a '<' and a '>' end or redirect the command, parentheses
 * are a subshell, and a '\' escapes whatever follows it and vanishes.
 * Several characters are on both sides, and are listed once with the
 * reason that bites first.
 *
 * It is the same shell half that build_system::unsafe_metacharacter()
 * asks of a path, written out again here rather than asked of that
 * function, because a name needs more than a path does: a path never
 * lands on the left of a rule, so it has no reason to fear a '#' or an
 * '='.  A '`' isn't here because the Configfile reader has already run
 * everything between two of them as a command, or refused the line
 * when there was only one, by the time any name gets this far.
 *
 * That none of these ever built is what makes this a refusal rather
 * than one of strict.h++'s warnings: there is no old Configfile that
 * works today and would stop working, only ones that configure quietly
 * and then fail inside make with an error about a line of generated
 * text, or that build a file with a different name from the one asked
 * for.
 *
 * Quoting or escaping them was the other way out, and doesn't go far
 * enough to be worth starting.  make has a backslash escape for a '#'
 * and a ':' in some places and not in others, none at all for an '='
 * at the start of what it takes for an assignment, and the shell half
 * is the quoting problem the manual's "odd behavior" section already
 * explains is a rewrite of every recipe in every backend.
 *
 * What isn't here is as deliberate as what is, and it isn't a promise
 * that everything else is safe.  Dashes, dots, underscores and
 * non-ASCII letters are ordinary characters to both make and the
 * shell, which is all a name needs.  The glob characters -- '*', '?',
 * '[' -- and '%' do build today, by the luck of there being nothing
 * for them to match, and refusing names that work is a change for a
 * strict.h++ warning to make if anyone ever wants it made.  And only
 * names are asked at all, since a COMPILEOPTS or a LINKOPTS is a
 * command line that never becomes a target and has every right to an
 * "-DX=a:b" or a '#' in it. */
static std::string make_special_character(char c)
{
    switch (c) {
    case '#':
        return "make reads a '#' anywhere on a rule line as the start of"
               " a comment, so everything after it -- the rest of the name"
               " and the rest of the rule -- is thrown away";
    case ':':
        return "make reads a ':' on a rule line as the end of the targets"
               " and the start of what they depend on, so the name is cut"
               " in two and the rule comes out a different shape";
    case '=':
        return "make reads a line with an '=' in it before its ':' as a"
               " variable assignment rather than a rule, which leaves the"
               " recipe below it belonging to nothing";
    case ';':
        return "make reads a ';' on a rule line as the end of the"
               " prerequisites and the start of a recipe, so the rest of"
               " the name becomes a command and the rule comes out a"
               " different shape";
    case '|':
        return "make reads a '|' on a rule line as the start of the"
               " order-only prerequisites, and the shell reads it in a"
               " recipe as a pipe, so neither ever sees one name";
    case '$':
        return "make reads a '$' as the start of a variable expansion, so"
               " what is built is named by whatever that expansion comes"
               " to rather than by what was written";
    case '(':
    case ')':
        return std::string("make reads a name spelled \"a(b)\" as")
               + " member b of archive a, and the shell reads a '" + c
               + "' in a recipe as the edge of a subshell";
    case '&':
        return "the name is pasted bare into the recipes that build it,"
               " where the shell reads a '&' as the end of one command"
               " run in the background and the start of another";
    case '<':
    case '>':
        return std::string("the name is pasted bare into the recipes that")
               + " build it, where the shell reads a '" + c + "' as a"
               + " redirection";
    case '\\':
        return "the name is pasted bare into the recipes that build it,"
               " where the shell reads a '\\' as escaping the character"
               " after it and drops it, so the file built is not the one"
               " named";
    case '\'':
    case '"':
        return std::string("the name is pasted bare into the recipes that")
               + " build it, where the shell reads a '" + c + "' as the"
               + " start of a quoted string that never ends";
    default:
        return "";
    }
}

/* Refuses "cmd" outright when it names a target or a source with one
 * of make_special_character()'s characters in it.  Only the first one
 * found is named: a diagnostic about one character is one that says
 * exactly what to change, and the next run names the next one. */
static void refuse_make_special_character(const command::ptr& cmd)
{
    if (names_a_make_target(cmd->type()) == false)
        return;

    for (const auto& c: cmd->data()) {
        auto why = make_special_character(c);
        if (why.size() == 0)
            continue;

        std::cerr << std::to_string(cmd->debug()) << "\n"
                  << "  error: " << std::to_string(cmd->type())
                  << " has a '" << c << "' in it: '" << cmd->data()
                  << "'\n"
                  << "  this is the name of something the Makefile builds,"
                  << " and " << why << "\n"
                  << "  rename it without the '" << c << "' -- letters,"
                  << " digits, '-', '_' and '.' are all safe -- and write"
                  << " that name here\n";
        abort();
    }
}

/* The refusal of a line written with the wrong operator.  Which of
 * the two a command takes is not something anybody can guess from
 * its name -- LIBDIR names one place and so is set, SOURCES names
 * several and so is added to -- so saying which one it takes is not
 * enough on its own: the line it is about has to be named, since in a
 * tree of Configfiles the same command is written dozens of times,
 * and the rewrite is given in full so it can be pasted over the old
 * one.
 *
 * The rewrite is spelled with the command as it was written rather
 * than as it is processed: a HEADERSRC reaches here as a HEADERS and
 * then a SOURCES, and a TESTS[network] is a TESTS with a name in
 * brackets, and neither is what the line said. */
static void refuse_operator(const command::ptr& cmd,
                            const std::string& wanted)
{
    auto written = std::to_string(cmd->type());
    if (cmd->qualifier().size() > 0)
        written += "[" + cmd->qualifier() + "]";
    auto words = string_utils::split_char(cmd->debug()->line(), " ");
    if (words.size() >= 2 && words[1] == cmd->operation())
        written = words[0];

    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: Command "
              << std::to_string(cmd->type())
              << " only supports '" << wanted << "', but given "
              << cmd->operation()
              << "\n";

    /* Anything other than the two operators there are is somebody
     * reaching for one there isn't -- a '-=' most of all, to take
     * back something an earlier line added.  Swapping in the right
     * operator would turn their removal into an addition, so the
     * advice is about the line that added it instead. */
    if (cmd->operation() != "=" && cmd->operation() != "+=") {
        std::cerr << "  '" << cmd->operation() << "' is not an"
                  << " operator: a Configfile line either sets something"
                  << " with '=' or adds to it with '+=', and no line can"
                  << " take back what an earlier one added\n"
                  << "  delete the line that added it, or write '"
                  << written << " " << wanted << " " << cmd->data()
                  << "' if this was meant to "
                  << (wanted == "=" ? "set it" : "add to it")
                  << "\n";
        return;
    }

    std::cerr << "  write '" << written << " " << wanted << " "
              << cmd->data() << "'\n";
}

/* An absolute PREFIX spelled the one way, so that "/opt/thing/" and
 * "/opt//thing" are the same prefix as "/opt/thing" everywhere it is
 * pasted.  A directory is joined onto the prefix with a '/' of its own
 * (context::installed()), which is why a trailing slash matters at
 * all: "/opt/thing/" became "/opt/thing//libexec" in
 * __PCONFIGURE__LIBEXEC and "/opt/thing//lib" in the RUNPATH, strings
 * that compare unequal to the ones a program built from the other
 * spelling sees.
 *
 * Only runs of '/' are collapsed and a trailing one dropped.  A ".."
 * is left exactly as written: whether "/opt/link/.." is "/opt" depends
 * on what "link" is on the machine the program is installed on, which
 * nothing here can see.  "/" on its own stays "/", since an empty
 * __PCONFIGURE__PREFIX would be telling the program it lives nowhere;
 * context::installed() knows not to put a second '/' after that one. */
static std::string normalized_prefix(const std::string& written)
{
    std::string out;
    for (const auto& c: written) {
        if (c == '/' && out.size() > 0 && out.back() == '/')
            continue;
        out += c;
    }

    if (out.size() > 1 && out.back() == '/')
        out.pop_back();

    return out;
}

/* Refuses a command that says how a static archive is linked.  An
 * archive is never linked -- "ar" copies objects into it and that is
 * all -- so a LINKER on a "libfoo.a" names a linker that never runs,
 * and since the format has nowhere to write down that its members need
 * some other library, a DEPLIBS or a LINKOPTS on one would be read by
 * nothing either.  They used to be read: before LIBRARIES built
 * archives, "libfoo.a" was a shared object wearing an archive's name,
 * linked by its LINKER and recording its dependencies the way any
 * shared object does, so whatever linked it got them for free.
 * Accepting the line now and dropping it would turn that into
 * undefined references in some other target's link, or a link done by
 * a different linker than the Configfile asked for, far from the line
 * that stopped working -- so it stops here instead and says where the
 * line has to go. */
static void refuse_under_static_archive(const command::ptr& cmd,
                                        const context::ptr& tos,
                                        const std::string& command_name)
{
    if (tos->is_static_archive() == false)
        return;

    /* "libsub.a" is what the Configfile wrote, "sub" is what a DEPLIBS
     * of it says, and "libsub.so" is the same library built shared. */
    const auto& archive = tos->cmd->data();
    auto stem = archive.substr(0, archive.size() - 2);
    auto deplib = stem.compare(0, 3, "lib") == 0 ? stem.substr(3) : stem;

    /* A LINKER isn't something an archive could have recorded, it's
     * the program that would have made one, so it gets its own reason
     * -- but the same place to go, since the programs that link the
     * archive are the ones that run a linker over its code. */
    bool linker = command_name == "LINKER";

    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: " << command_name << " under '"
              << archive << "', which is a static archive\n"
              << "  an archive is put together by ar rather than linked,"
              << (linker
                  ? " and no linker ever runs for it"
                  : " and has no way to record what it needs")
              << ", so nothing would ever read this\n"
              << "  write '" << command_name << " " << cmd->operation()
              << " " << cmd->data() << "' under each BINARIES or"
              << " LIBRARIES that has a 'DEPLIBS += "
              << deplib << "', or name the"
              << " library '" << stem + ".so"
              << (linker
                  ? "' to build a shared one that this links\n"
                  : "' to build a shared one that records it itself\n");
    abort();
}

void command_processor::process(const command::ptr& cmd)
{
    /* Said here rather than inside the switch because TESTSRC and
     * HEADERSRC are each two commands wearing one hat and go through
     * process_one() twice: this is about the line as it was written,
     * and the line was written once. */
    /* Also about the line as it was written, and for the same
     * reason: the brackets are on the line once however many commands
     * that line turns out to be. */
    if (cmd->qualifier().size() > 0
        && takes_a_qualifier(cmd->type()) == false) {
        std::cerr << std::to_string(cmd->debug()) << "\n"
                  << "  error: "
                  << std::to_string(cmd->type())
                  << " takes no name in brackets\n"
                  << "  only TESTS and TESTSRC take one, and what it says"
                  << " is which test suite the test joins\n"
                  << "  write '"
                  << std::to_string(cmd->type())
                  << " " << cmd->operation()
                  << "' with nothing between the command and the"
                  << " operator\n";
        abort();
    }

    /* Asked after the command has been read and its brackets
     * checked, so that a misspelled command is reported as one rather
     * than as a value that went missing.  The operator is left to
     * process_one(), which is the only place that knows it: a list of
     * options given nothing still has to be given it with a '+='. */
    if (cmd->printed_nothing() == true
        && can_be_given_nothing(cmd->type()) == false) {
        std::cerr << std::to_string(cmd->debug()) << "\n"
                  << "  error: the command in backticks printed nothing,"
                  << " which leaves " << std::to_string(cmd->type())
                  << " with no value\n"
                  << "  " << std::to_string(cmd->type()) << " can't be"
                  << " given nothing, however that comes about: only"
                  << " CROSS_COMPILE and the lists of options"
                  << " (COMPILEOPTS, LINKOPTS, CONFIGUREOPTS, MAKEOPS)"
                  << " can\n"
                  << "  make the command print a value"
                  << " (\"`cmd || echo default`\"), write the value out,"
                  << " or remove the line\n";
        abort();
    }

    /* PREFIX names a path too, but a space in one is refused outright
     * by process_one() -- see the comment there for why that one has
     * no compatibility to keep -- and a warning just ahead of the
     * error that supersedes it would only be noise. */
    if (names_a_path(cmd->type()) == true
        && cmd->type() != command_type::PREFIX
        && cmd->data().find(' ') != std::string::npos) {
        _stack.top()->strictness.complain(
            strict_since::v0_13(),
            cmd->debug(),
            "everything after the operator is one path, so this names a"
            " single file with a space in its name",
            "write one " + std::to_string(cmd->type())
            + " line per file -- the rule this makes gets split back up"
            " by make into targets nobody meant");
    }

    /* Also of the line as it was written, so a TESTSRC is refused
     * once, as a TESTSRC, rather than as whichever of its two
     * commands happened to get there first. */
    refuse_make_special_character(cmd);

    process_one(cmd);
}

void command_processor::process_one(const command::ptr& cmd)
{
    auto tos = _stack.top();

    switch (cmd->type()) {
    /* Whether ptest should count a test that calls abort() as a FAIL
     * instead of an EROR.  ptest's own default is right for the
     * general case -- see the comment on _abrt_is_fail in
     * command_processor.h++ for why a signal death stays an EROR
     * unless a project opts in -- so this just bakes "--abrt-is-fail"
     * for this project's check directory onto every "make check"/"make
     * report" recipe that reads it, this project's own and any
     * parent's, the same way AUTORECONFIGURE bakes in a different
     * answer to a different question. */
    case command_type::ABRT_IS_FAIL:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT}, cmd);

        if (cmd->data() != "true" && cmd->data() != "false") {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: '" << cmd->data() << "' is not"
                      << " 'true' or 'false'\n"
                      << "  " << std::to_string(cmd->type())
                      << " asks whether a crash is a FAIL or an EROR,"
                      << " and there are two answers\n";
            abort();
        }

        _abrt_is_fail = cmd->data() == "true";
        _abrt_is_fail_cmd = cmd;
        return;
    }

    case command_type::AUTODEPS:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        if (cmd->data() == "true") {
            tos->autodeps = true;
            tos->autodeps_debug = cmd->debug();
            return;
        }

        if (cmd->data() == "false") {
            tos->autodeps = false;
            tos->autodeps_debug = cmd->debug();
            return;
        }

        std::cerr << cmd->data() << " is not boolean\n";
        abort();
        return;
    }

    /* Whether the dependencies of this project's sources are worked
     * out here, once, or by the build every time it runs.
     *
     * What pconfigure writes down is what it saw when it ran: which
     * headers a source reads, and which sources sit behind those
     * headers.  A source that starts including something new has
     * changed the answer, and nothing in the build knows that -- so
     * the Makefile goes on describing a tree that no longer exists
     * until somebody remembers to configure again.  Turning this on
     * moves that question into make, where the file that answers it
     * is a file with a rule and a timestamp like any other. */
    case command_type::AUTORECONFIGURE:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        /* It says how this project is built rather than how one
         * target is, so it belongs to the project the way a PREFIX
         * does.  Landing on whatever happened to be open above it
         * would make where the line sits change what it means. */
        clear_until({context_type::DEFAULT}, cmd);

        if (cmd->data() != "true" && cmd->data() != "false") {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: '" << cmd->data() << "' is not"
                      << " 'true' or 'false'\n"
                      << "  " << std::to_string(cmd->type())
                      << " asks who works out this project's"
                      << " dependencies, and there are two answers\n";
            abort();
        }

        /* A subproject is read at the point its line appears, so a
         * tree that was already read was read under whatever the
         * answer was then.  Changing it afterwards writes one
         * project's Makefile one way and its subprojects' the other,
         * and nothing says so: the tree just builds with half of it
         * frozen at configure time.
         *
         * Only a line that would change the answer is a mistake.
         * Saying again what a project was already going to do costs
         * nothing and is how a Configfile that spells out its
         * defaults reads. */
        if (_read_a_subproject == true
            && (cmd->data() == "true") != _root->autoreconfigure) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: a subproject has already been read\n"
                      << "  " << std::to_string(cmd->type())
                      << " reaches the subprojects below it, and the"
                      << " ones above it were read without it\n"
                      << "  move it above the first SUBPROJECTS or"
                      << " BOOTSTRAP line\n";
            abort();
        }

        _autoreconfigure = cmd->data() == "true";
        _autoreconfigure_cmd = cmd;

        /* Said again on the root context, which is the only thing a
         * subproject is handed: project::read() gives the child its
         * parent's root_context() and nothing else, so a value that
         * lives only on the processor is a value the tree below can't
         * see.  Nothing reads it there yet. */
        _root->autoreconfigure = _autoreconfigure;
        return;
    }

    case command_type::BINARIES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        refuse_target_leaving_project(cmd);

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::BINARY, cmd);

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        auto ctx = _stack.top();
        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

        return;
    }

    /* The vendored pconfigure source this project builds itself with.
     *
     * A project whose build system has to be built first hands
     * whoever clones it a problem before it hands them a build: they
     * have to find out that pconfigure exists, get one, and get the
     * right one.  Naming a tree here moves that into the Makefile,
     * where it is one more thing make knows how to build.
     *
     * The line points at a source tree rather than at a binary
     * because a binary is a thing somebody already built, which is
     * exactly what a fresh checkout hasn't got. */
    case command_type::BOOTSTRAP:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        /* The path lands in PCONFIGURE_SRCPATH and in the recipes
         * that build and distclean the tree, exactly as a
         * SUBPROJECTS one does. */
        refuse_unsafe_metacharacter(cmd, "BOOTSTRAP");

        clear_until({context_type::DEFAULT}, cmd);

        /* Only the project make gets run in has a Makefile anybody
         * types "make" at.  A subproject's Makefile is included by
         * that one, so a second set of these rules down there would
         * be a second recipe for the same file -- and make would
         * quietly pick one of them. */
        if (_base.size() != 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: " << std::to_string(cmd->type())
                      << " in a subproject has no Makefile to write\n"
                      << "  the rules it writes go in the Makefile make"
                      << " is run at, which is the one above this\n"
                      << "  move the line to the Configfile of the"
                      << " project that pulls this one in\n";
            abort();
        }

        /* The tree is read as a subproject, so it inherits the same
         * restriction: a project that moved its source root can't
         * also root subprojects, because a subproject's sources and
         * its build output would stop being in the same place and one
         * variable can't mean both. */
        if (_srcpath != ".") {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: " << std::to_string(cmd->type())
                      << " doesn't work alongside SRCPATH, which has"
                      << " rooted this project at '" << _srcpath
                      << "'\n"
                      << "  the vendored tree is built where it sits,"
                      << " like any other subproject, and a project"
                      << " whose sources are somewhere else has no one"
                      << " directory to build it in\n";
            abort();
        }

        auto path = file_utils::normalize_directory(cmd->data());

        if (path.size() == 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: " << std::to_string(cmd->type())
                      << " can't point at the project itself\n"
                      << "  it names the vendored pconfigure this"
                      << " project is built with, which is a tree"
                      << " inside this one\n";
            abort();
        }

        /* Everything here is named relative to where pconfigure ran,
         * and this one ends up in a Makefile that gets committed --
         * so a path that leaves the tree is a path that only means
         * anything on the machine it was written on.  An absolute
         * path is the same mistake spelled more plainly: even one
         * that happens to name a directory inside this checkout names
         * it only where this checkout is, and every other clone gets
         * a Makefile that bootstraps from somebody else's home
         * directory. */
        if (path.size() > 0 && path[0] == '/') {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: " << std::to_string(cmd->type())
                      << " can't be an absolute path: '" << cmd->data()
                      << "'\n"
                      << "  the Makefile it writes is meant to be"
                      << " committed, and an absolute path names this"
                      << " checkout only where it sits on this machine\n"
                      << "  name the vendored tree relative to this"
                      << " Configfile\n";
            abort();
        }

        if (path.compare(0, 3, "../") == 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: " << std::to_string(cmd->type())
                      << " can't reach outside the project\n"
                      << "  the Makefile it writes is meant to be"
                      << " committed, and a path out of the tree names"
                      << " nothing on anybody else's machine\n"
                      << "  vendor the pconfigure source into this tree"
                      << " and name it from here\n";
            abort();
        }

        /* The rest of what SUBPROJECTS asks of where a tree is, since
         * after this the tree is one: a vendored pconfigure checked
         * out under the object directory is removed by the next
         * distclean, and one reached through a symlink out of the
         * project is a tree this build writes into and distcleans
         * somewhere else -- which is also a committed Makefile
         * naming a link that only resolves here. */
        refuse_unsafe_subproject_location(cmd, path,
                                          _stack.top()->obj_dir);

        /* Asked now rather than left to make, because the usual way
         * to get here is a submodule nobody has checked out yet --
         * and an empty directory turns into a make error about a
         * missing Makefile, which says nothing about submodules. */
        if (access((path + "bootstrap.sh").c_str(), X_OK) != 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: '" << path << "' has no executable"
                      << " bootstrap.sh in it\n"
                      << "  that's the script that builds a pconfigure"
                      << " without one, so a tree without it can't be"
                      << " the tree this project bootstraps from\n"
                      << "  if it's a submodule, check it out: git"
                      << " submodule update --init " << cmd->data()
                      << "\n";
            abort();
        }

        _bootstrap = path;
        _bootstrap_cmd = cmd;

        /* Everything after the bootstrap is an ordinary subproject:
         * the tree is read the way any other one is, its Makefile
         * gets included, and the pconfigure in it is built by the
         * same dependency graph as everything else.  What is special
         * about it is only the two things nothing else needs -- a way
         * to build a first one with no pconfigure in hand, and a
         * Makefile that says so -- and neither of those is a reason
         * to invent a second way of tracking what the tree builds.
         *
         * A tree that a SUBPROJECTS also names is read once, since
         * that is true of any project two lines ask for. */
        _pending_subprojects.push_back({path, cmd});
        _named_subprojects.push_back(std::make_pair(path, cmd));

        return;
    }

    case command_type::BUILD_SYSTEMS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT}, cmd);

        /* Asking for one that's already here is how you get back to
         * it to say something more about it, which is exactly what
         * LANGUAGES does. */
        for (const auto& existing: _build_systems) {
            if (existing->name() != cmd->data())
                continue;
            _configure_target = existing;
            return;
        }

        auto added = build_system::create(cmd->data());
        if (added == NULL) {
            std::cerr << "Unable to find build system: '"
                      << cmd->data()
                      << "'\n"
                      << "Build System Set:\n";
            for (const auto& name: build_system::names())
                std::cerr << "  " << name << "\n";
            abort();
        }

        _build_systems.push_back(added);
        _configure_target = added;

        return;
    }

    /* COMPAT was going to be this, and never became anything: it has
     * been read and thrown away since it was added.  What it was
     * reaching for is what STRICT does, so it says so and stays
     * accepted, since a line that has never done anything can't have
     * been holding a project up. */
    case command_type::COMPAT:
        tos->strictness.complain(
            strict_since::v0_13(),
            cmd->debug(),
            "COMPAT is read and then thrown away -- it has never done"
            " anything",
            "delete the line; a project that wants to say which"
            " pconfigure it was written against wants STRICT");
        return;

    case command_type::COMPILEOPTS:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Backticks that printed nothing add nothing, and an empty
         * word in the list would be one more gap in a command line.
         * It's skipped only after the checks above, which are about
         * the line as written and hold whatever its value came to. */
        if (cmd->printed_nothing() == true)
            return;

        check_opts_target(cmd);
        _opts_target->add_compileopt(cmd->data());

        return;

    case command_type::COMPILER:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        check_opts_target(cmd);
        _opts_target->set_compiler(cmd->data());

        return;

    case command_type::CONFIG:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Reading it is left to whoever owns this, so that the
         * lines inside it get run at the point they're processed
         * rather than all at once up front. */
        _pending_configs.push_back(cmd);

        return;
    }

    /* A path the enumeration behind a CONFIG depends on, which is
     * not something the CONFIG itself can say.  An executable
     * Configfile that globs a directory of tests reads that directory
     * and prints what it found; the directory is an input to the
     * configuration exactly as the Configfile is, and until this
     * existed nothing watched it -- so adding a test changed no
     * watched file, the makefile was not rewritten, and the test was
     * on disk without being in the build.
     *
     * Deliberately NOT read.  Everything else that lands in this list
     * got there by being opened for lines, and a directory has none;
     * what it contributes is its mtime, which moves when an entry is
     * added or removed.  That is why a directory is the useful thing
     * to name here even though a file works too: a file already says
     * "I changed", while nothing else can say "something appeared
     * next to me".
     *
     * It is queued rather than registered, for take_pending_config's
     * reason: the path is relative to the project that wrote the
     * line, and project::process_line is what knows which project
     * that was. */
    case command_type::CONFIG_DEPS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        _pending_config_deps.push_back(cmd->data());

        return;
    }

    case command_type::CONFIGUREOPTS:
        if (_configure_target == NULL)
            goto no_configure_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Adds nothing, for COMPILEOPTS's reason. */
        if (cmd->printed_nothing() == true)
            return;

        _configure_target->add_configureopt(cmd->data(), cmd->debug());

        return;

    /* A variable to put on the command line of the make that builds a
     * vendored tree, where it beats whatever the tree's own Makefile
     * has to say about it.  Like a CONFIGUREOPTS this lands on
     * whichever subproject was opened last, or on a whole build
     * system when it was written after one of those. */
    case command_type::MAKEOPS:
        if (_configure_target == NULL)
            goto no_configure_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Adds nothing, for COMPILEOPTS's reason. */
        if (cmd->printed_nothing() == true)
            return;

        _configure_target->add_makeopt(cmd->data(), cmd->debug());

        return;

    /* A file a vendored tree produces.  Everything else about such a
     * tree hangs off one stamp that says it has been built, and a
     * stamp is not something anything else can name: this is what
     * turns a file the tree happens to write into a target that a
     * TESTDEPS or a link line can ask for. */
    case command_type::SUBPROJECT_TARGETS:
        if (_configure_target == NULL)
            goto no_configure_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        _configure_target->add_subproject_target(cmd->data(), cmd->debug());

        /* A TESTDEPS is resolved where it's written, so one written
         * above this line was read before the tree had been said to
         * produce anything -- and a path that could have named this
         * output was read as a path in the project instead.  Moving
         * one of the two lines is the whole fix, and nothing further
         * down would say which two lines they were: what make ends up
         * complaining about is a file nobody builds. */
        for (const auto& earlier: _plain_test_deps) {
            if (_configure_target->produces(earlier.in_obj) == false)
                continue;

            std::cerr << std::to_string(earlier.cmd->debug()) << "\n"
                      << "  error: this was read before the tree in '"
                      << _configure_target->source_dir()
                      << "' was said to produce it, on "
                      << std::to_string(cmd->debug()) << "\n"
                      << "  so it names a path in the project rather than '"
                      << earlier.in_obj << "'\n"
                      << "  put the SUBPROJECTS and its SUBPROJECT_TARGETS"
                      << " above the tests that wait for them\n";
            abort();
        }

        return;

    /* Which machine the things below this are being built for, said
     * the way every cross build has said it since kbuild: the name
     * the toolchain's programs all start with.
     *
     * This lands on whatever context is open rather than on the
     * current language, which is what makes it mean the same thing at
     * every scope it can be written at.  At the top of a Configfile
     * that's the whole project, and a project pulled in by a
     * SUBPROJECTS inherits it the same way it inherits a PREFIX;
     * after a BINARIES it's that one binary; after a SOURCES it's
     * that one file. */
    case command_type::CROSS_COMPILE:
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        _stack.top()->cross_compile = cmd->data();

        return;

    case command_type::DEPLIBS:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        if (_stack.top()->check_type({context_type::BINARY,
                                      context_type::LIBRARY,
                                      context_type::GENERATE,
                                      context_type::TEST,}) == false) {
            /* The two ways to get here want different advice.  After
             * a SOURCES the target is right there, one line up, and
             * this is LINKOPTS's mistake (which only warns, since a
             * link option on a source is merely ignored -- a library
             * dependency that is ignored is a link that fails later,
             * somewhere else).  Anywhere else there is no target at
             * all, and the line belongs under one. */
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: Attempted to add DEPLIB to a "
                      << std::to_string(_stack.top()->type)
                      << " context, which isn't supported\n"
                      << "  a DEPLIBS is a library something gets linked"
                      << " against, so it lands on a BINARIES, LIBRARIES,"
                      << " TESTS or GENERATE\n";
            if (_stack.top()->type == context_type::SOURCE)
                std::cerr << "  move it above the SOURCES, onto the"
                          << " target the file gets linked into\n";
            else
                std::cerr << "  write it below the BINARIES, LIBRARIES,"
                          << " TESTS or GENERATE line it is meant for\n";
            abort();
        }

        refuse_under_static_archive(cmd, _stack.top(), "DEPLIBS");

        _stack.top()->dep_libs.push_back(cmd->data());

        return;

    /* What a binary is allowed to ask the kernel for.  This is only
     * ever consulted on macOS, but it's accepted everywhere: a
     * Configfile shouldn't have to know which machine is reading it,
     * and a platform with nothing to sign has nothing to do here. */
    case command_type::ENTITLEMENTS:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        /* Read relative to the project the same way a SOURCES is, and
         * checked the same way: nothing before this asked whether an
         * ENTITLEMENTS climbed out of the project or named an absolute
         * path, so "ent.plist;>/abs/PWNED;true" reached the codesign
         * command line in languages/cxx.c++ unquoted and unquestioned.
         * There is no compatibility argument for letting a plain
         * escape stand once it is noticed, the way there is for the
         * bare ".." a SRCDIR still warns about -- nothing was ever
         * relying on this, because nothing before this asked. */
        auto leaves = leaves_the_project(cmd->data());
        if (leaves.size() > 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: ENTITLEMENTS names a file outside this"
                      << " project: " << leaves << "\n"
                      << "  write it inside the project, like"
                      << " 'ENTITLEMENTS = app.plist'\n";
            abort();
        }

        /* After the escape check above, for the same reason LIBDIR
         * asks after its own: a value with both a '$' and a '(' keeps
         * the more specific "make expansion" answer. */
        refuse_unsafe_metacharacter(cmd, "ENTITLEMENTS");

        /* Only a whole linked thing is ever signed, so an
         * ENTITLEMENTS that landed below one is asking for nothing --
         * and asking for nothing quietly is worse here than
         * elsewhere, since what comes out is a binary that runs until
         * it reaches the thing it wasn't allowed to do.
         *
         * A TEST is not one of those.  It reads like a place nothing
         * gets linked, but a test is built into a program of its own:
         * the language duplicates the context into a BINARY and links
         * and signs that, entitlements and all.  So a test that needs
         * to be allowed to do something says so exactly here, and
         * warning about it would be telling somebody to delete the
         * line that was doing the work. */
        if (tos->check_type({context_type::SOURCE,
                             context_type::HEADER,
                             context_type::GENERATE,}) == true)
            tos->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                "ENTITLEMENTS written under a "
                + std::to_string(tos->type)
                + " asks for nothing: only a whole linked binary is"
                " signed",
                "move it up so it sits directly under the BINARIES or"
                " LIBRARIES it's about");

        tos->entitlements = cmd->data();

        return;
    }

    /* A framework name is an Apple ld64 concept ("-framework Foo") with
     * no ELF equivalent, so it gets the same treatment as ENTITLEMENTS
     * just above: a plain field on the context rather than something
     * that goes through the opts_target interface LINKOPTS uses, which
     * exists so that COMPILEOPTS/LINKOPTS can target either a context
     * or a language's own defaults -- FRAMEWORKS, like ENTITLEMENTS,
     * only ever means anything on the one linked-and-signed context
     * that's actually open, never as a language-wide default.  It's
     * accepted on every platform, so a Configfile never has to ask
     * which machine is reading it, and languages/cxx.c++ only ever
     * turns it into a "-framework" argument when what's being linked
     * is actually a Mach-O -- elsewhere it's silently nothing, which is
     * the point: spelling "-framework Foo" out by hand in a LINKOPTS
     * would instead hard-fail every linker that isn't Apple's. */
    case command_type::FRAMEWORKS:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Same reasoning as ENTITLEMENTS above: only a whole linked
         * binary is signed, so a FRAMEWORKS that landed under a
         * compile-only context asks for nothing. */
        if (tos->check_type({context_type::SOURCE,
                             context_type::HEADER,
                             context_type::GENERATE,}) == true)
            tos->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                "FRAMEWORKS written under a "
                + std::to_string(tos->type)
                + " asks for nothing: only a whole linked binary is"
                " signed",
                "move it up so it sits directly under the BINARIES or"
                " LIBRARIES it's about");

        /* A framework name reaches the linker command line as text
         * the same way an ENTITLEMENTS path reaches codesign's --
         * same hazard, same refusal. */
        refuse_unsafe_metacharacter(cmd, "FRAMEWORKS");
        refuse_under_static_archive(cmd, tos, "FRAMEWORKS");

        tos->add_framework(cmd->data());

        return;

    /* A TGENERATE is a GENERATE whose script lives with the tests
     * rather than with the sources: a generator that exists only to
     * build a fixture for the tests belongs next to them.  Everything
     * else -- the checks on the name, what gets written where, how the
     * script is run -- is the same, so it is the same code, and the
     * only question asked of which one was written is where to look
     * for the script. */
    case command_type::GENERATE:
    case command_type::TGENERATE:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Named and checked the same way a SOURCES is, since this
         * becomes one a few lines down -- with ".proc" stuck on the
         * end -- and a GENERATE with no check of its own would reach
         * that SOURCES having already skipped the one thing that would
         * have refused it. */
        {
            auto leaves = leaves_the_project(cmd->data());
            if (leaves.size() > 0) {
                std::cerr << std::to_string(cmd->debug()) << "\n"
                          << "  error: " << std::to_string(cmd->type())
                          << " names a file outside this"
                          << " project: " << leaves << "\n"
                          << "  write it inside the project, like '"
                          << std::to_string(cmd->type())
                          << " += gen.h'\n";
                abort();
            }
        }

        /* After the escape check above, for the same reason LIBDIR
         * asks after its own: a value with both a '$' and a '(' keeps
         * the more specific "make expansion" answer. */
        refuse_unsafe_metacharacter(cmd, std::to_string(cmd->type()));

        /* Named by the path it reaches, the way a SOURCES is and for
         * a sharper version of the same reason: the name is pasted
         * onto the generated-file directory to name the rule's target,
         * while a consumer that includes the header reaches it by the
         * path pinclude found, which has no "./" in it.  Spelled as
         * written, "./gen.h" gave make a rule for obj/proc/./gen.h and
         * an object depending on obj/proc/gen.h -- one file to the
         * kernel, two to make -- so nothing joined the generator to
         * what read its output, and a parallel build happily compiled
         * against the header before regenerating it.  Normalized only
         * after both checks above, since normalizing can take apart
         * what they look for. */
        auto generated = cmd->with_data(file_utils::normalize_path(cmd->data()));

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::GENERATE, generated);

        /* The script is found as the context's source directory with
         * the name and ".proc" on the end, so pointing that at the
         * test directory is all a TGENERATE needs.  It is set here,
         * before the script's SOURCES is pushed, so that the script
         * inherits it too; and it is the project's test directory
         * rather than "test", so a subproject's TGENERATE finds the
         * script in its own tree.  Nothing else reads a GENERATE's
         * source directory: what it writes goes in gen_dir. */
        if (cmd->type() == command_type::TGENERATE)
            _stack.top()->src_dir = _stack.top()->test_dir;

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        dup_tos_and_push(context_type::SOURCE,
                         std::make_shared<command>(
                             cmd->type(),
                             "+=",
                             generated->data() + ".proc",
                             cmd->debug()
                             )
            );

        return;
    }

    case command_type::HDRDIR:
        goto unimplemented;

    case command_type::HEADERS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* A HEADERSRC is handled as this HEADERS and then a SOURCES,
         * and its SOURCES half asks the same leaves_the_project()
         * question and refuses in the words of the line as written.
         * Asking it here as well would get there first and refuse a
         * HEADERSRC as a HEADERS, sending whoever reads it looking
         * for a line that isn't in the Configfile; nothing between
         * here and that SOURCES half writes anything, so letting it
         * past costs nothing. */
        if (cmd->written_as() != command_type::HEADERSRC)
            refuse_target_leaving_project(cmd);

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::HEADER, cmd);

        _stack.top()->bin_dir = _stack.top()->hdr_dir;

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        return;
    }

    case command_type::LANGUAGES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT}, cmd);
        tos = _stack.top();

        if (tos->languages->search(cmd->data()) != NULL) {
            set_opts_target(tos->languages->search(cmd->data()));
            return;
        }

        auto new_language = language_list::global_search(cmd->data());

        if (new_language == NULL) {
            /* Not a list of every name registered, since some of
             * those are pconfigure's own plumbing (implicit_h,
             * gen_proc, phony) rather than anything a Configfile asks
             * for.  Nor a guess at how the name went wrong: a typo, a
             * compiler's name in place of the language's and a
             * language this pconfigure is too old for all end up
             * here, and the fix for each is the same. */
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: Unable to find language: '"
                      << cmd->data()
                      << "'\n"
                      << "  write the name of a language pconfigure knows,"
                      << " like 'LANGUAGES += c' or 'LANGUAGES += c++'\n";
            abort();
        }

        auto clone = language::ptr(new_language->clone());
        tos->languages->add(clone);
        set_opts_target(clone);

        return;
    }

    case command_type::LIBDIR:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT}, cmd);

        /* Where a library lands is an output directory, and every
         * output directory in the run is a line of "make distclean":
         * the recipe is an "rm -rf" of each one, because everything
         * in there is output this build knows how to make again.
         * That is what makes this the directory command that can't be
         * let through with a warning.  A "LIBDIR = /usr/lib" reads
         * like a line about where libraries go and arrives as "rm -rf
         * '/usr/lib'"; a "LIBDIR = $(HOME)/lib" gets there with
         * make's help, since the quotes in that recipe are the
         * shell's and make has already had its turn on the line.
         *
         * Refused rather than warned about, which is the other thing
         * this project does with a line that quietly means something
         * nobody meant.  strict.h++ is where that choice is written
         * down and the argument there is compatibility: a line some
         * project is relying on cannot simply become an error.  That
         * argument doesn't reach this one.  What a project would be
         * relying on here is "make distclean" removing a directory
         * outside itself, which is to say relying on the one outcome
         * nothing can put back -- and one it could only have found
         * out about by losing something.  A refusal at configure time
         * names the line and costs a one-line edit; the warning costs
         * whatever was in the directory.
         *
         * It is also the answer the rest of the tree already gives.
         * Every vendored build system's install prefix goes through
         * build_system::checked_install_dir(), which refuses these
         * same spellings for a path with a great deal less at stake:
         * a prefix is confined to the object directory and distclean
         * only ever reaches it by covering that directory, while this
         * one is pasted into the "rm -rf" outright. */
        auto leaves = leaves_the_project(cmd->data());
        if (leaves.size() > 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: LIBDIR names a directory outside this"
                      << " project: " << leaves << "\n"
                      << "  'make distclean' is an 'rm -rf' of every"
                      << " output directory this build has, and a LIBDIR"
                      << " is one of them -- so this line hands a"
                      << " directory nothing in this build owns to an"
                      << " 'rm -rf'\n"
                      << "  write it inside the project, like"
                      << " 'LIBDIR = lib'\n";
            abort();
        }

        /* Asked after leaves_the_project() above rather than before
         * it, so that a value with both -- "$(HOME)/lib" is a '$' and
         * two parentheses -- keeps the more specific answer: make
         * expands the whole of that before a shell ever reads any of
         * it, which leaves_the_project() already has a name for. */
        refuse_unsafe_metacharacter(cmd, "LIBDIR");

        _stack.top()->lib_dir = _base + cmd->data();
        return;
    }

    case command_type::LIBEXECS:
    case command_type::TESTEXECS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        refuse_target_leaving_project(cmd);

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::BINARY, cmd);

        auto ctx = _stack.top();
        if (cmd->type() == command_type::TESTEXECS) {
            /* TESTEXECs are just LIBEXECs that only the tests are
             * expected to run, so they're built but never installed. */
            ctx->bin_dir = ctx->testexec_dir;
            ctx->install = false;
        } else {
            ctx->bin_dir = ctx->libexec_dir;
        }

        set_opts_target(ctx);
        _output_contexts.push_back(ctx);

        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

        return;
    }

    case command_type::LIBRARIES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        refuse_target_leaving_project(cmd);

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::LIBRARY, cmd);

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        /* What a test of a library is handed, and what its check rule
         * waits on, is the library -- and a library is built into the
         * LIBDIR, not the BINDIR the programs go to.  Naming the BINDIR
         * here makes the rule wait on a file no rule makes, so "make
         * check" stops with "No rule to make target" before a single
         * test has run, in this project and in any project that
         * includes it as a subproject.  This is the same path
         * project.c++ and the languages build the library at. */
        auto ctx = _stack.top();
        ctx->test_binary = ctx->lib_dir + "/" + ctx->cmd->data();

        return;
    }

    case command_type::LINKER:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        check_opts_target(cmd);

        /* As with LINKOPTS, only when it lands on the archive itself:
         * one above every target is the language's linker, and still
         * meant for everything that does get linked. */
        if (_opts_target == _stack.top())
            refuse_under_static_archive(cmd, _stack.top(), "LINKER");

        _opts_target->set_linker(cmd->data());

        return;

    case command_type::LINKOPTS:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Adds nothing, for COMPILEOPTS's reason. */
        if (cmd->printed_nothing() == true)
            return;

        check_opts_target(cmd);

        /* A source file is compiled and never linked, so a link
         * option that landed on one is read by nothing at all: every
         * language asks the target for its link options and the
         * target is the binary or the library. */
        if (_stack.top()->type == context_type::SOURCE
            && _opts_target == _stack.top())
            _stack.top()->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                "LINKOPTS written after a SOURCES lands on that one file,"
                " and a source file is compiled rather than linked, so"
                " nothing ever reads it",
                "move it above the SOURCES, onto the target the file gets"
                " linked into");

        /* Only when the option is landing on the archive itself: a
         * LINKOPTS above every LIBRARIES is a language-wide default,
         * and one an archive doesn't use is still meant for every
         * program next to it. */
        if (_opts_target == _stack.top())
            refuse_under_static_archive(cmd, _stack.top(), "LINKOPTS");

        _opts_target->add_linkopt(cmd->data());

        return;

    /* A target that is a name and nothing else.  This exists so that
     * a project that has tests but nothing to hang them off can still
     * have them: a TESTS belongs to the thing it exercises, and the
     * thing an integration test exercises is several other projects
     * at once rather than any one program.  The alternative was a
     * binary that does nothing, which builds and installs a program
     * nobody wants and makes PTEST_BINARY point at it. */
    case command_type::PHONY:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::PHONY, cmd);

        auto ctx = _stack.top();
        _output_contexts.push_back(ctx);

        /* There is no program here, so there is nothing for a test to
         * be handed.  Saying so outright is the whole difference
         * between this and the dummy binary it replaces: a test that
         * reaches for PTEST_BINARY under one of these finds nothing,
         * rather than finding a path to a program that does nothing.
         *
         * An opts target isn't set either.  A COMPILEOPTS here would
         * have nothing to compile, and the stale-target warning is a
         * better answer for it than quietly accepting it would be. */
        ctx->test_binary = "";

        return;
    }

    case command_type::PREFIX:
        if (cmd->check_operation("=") != true)
            goto bad_op_eq;

        /* The metacharacter check, and deliberately not
         * leaves_the_project()'s: an install prefix is legitimately
         * absolute -- "/usr/local" is the default -- and it is spliced
         * into an install recipe unquoted (languages/cxx.c++,
         * languages/bash.c++, languages/pkgconfig.c++ and
         * languages/implicit_h.c++ all paste it after "$(DESTDIR)"
         * raw), which is exactly the shape a semicolon turns into a
         * second command. */
        refuse_unsafe_metacharacter(cmd, "PREFIX");

        /* Whitespace is refused here rather than warned about the way
         * every other path's is (see process()).  The warning exists
         * for old projects that wrote a space and got away with it,
         * and nothing ever got away with one in a PREFIX: it is pasted
         * unquoted into every compile line as -D__PCONFIGURE__PREFIX
         * and into every install and uninstall recipe, so the compiler
         * is handed half a path and a stray file name, and "make
         * uninstall" removes a directory named after the first half.
         * There's no build to keep working. */
        if (cmd->data().find_first_of(" \t\v\f\r") != std::string::npos) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: PREFIX has whitespace in it: '"
                      << cmd->data() << "'\n"
                      << "  the prefix reaches every compile line and"
                      << " every install recipe unquoted, where a space"
                      << " splits it into two words: the compiler is"
                      << " handed half a path and a stray file name, and"
                      << " 'make uninstall' removes a directory named"
                      << " after the first half\n"
                      << "  install to a directory without whitespace in"
                      << " its name, like 'PREFIX = /opt/my-thing'\n";
            abort();
        }

        /* An install prefix is an absolute path by definition: it is
         * where the installed program finds itself, compiled into it
         * as __PCONFIGURE__PREFIX and __PCONFIGURE__LIBEXEC and linked
         * into it as the RUNPATH its libraries come from.  A relative
         * one is pasted into the install recipes after $(DESTDIR) as
         * though it were absolute, while the program is told it lives
         * at "opt/thing" and looks for its libraries in "opt/thing/lib"
         * underneath whatever directory it happens to be run from --
         * which is a program that only starts from /, and one that
         * loads libraries out of the current directory when it does.
         * Nobody meant that, so the line is refused where it was
         * written rather than built.
         *
         * The suggestion is a fixed example rather than the value with
         * a '/' stuck on the front: what "~/foo", "./install" or
         * "../x" were relative to isn't anything this can know, and
         * "/~/foo" or "/../x" would be pointing somebody at a
         * directory they never meant just as confidently. */
        if (cmd->data().size() == 0 || cmd->data()[0] != '/') {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: PREFIX isn't an absolute path: '"
                      << cmd->data() << "'\n"
                      << "  the prefix is compiled into the program as"
                      << " where it was installed, and linked into it as"
                      << " where its libraries are, so a relative one"
                      << " is read from whatever directory the program"
                      << " is run from rather than from the one it was"
                      << " installed into\n"
                      << "  write the whole path to the directory it"
                      << " installs into, starting with a '/', like"
                      << " 'PREFIX = /opt/thing'\n";
            abort();
        }

        tos->prefix = normalized_prefix(cmd->data());

        return;

    case command_type::SOURCES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Checked the same way a SRCDIR is, but refused rather than
         * warned about: a source file's path is pasted onto the
         * object directory to name the object it compiles to (see
         * build_system::output_dir()'s sibling logic in the
         * language implementations), so a "../../x.c" doesn't merely
         * read a file from outside the project -- it writes an object
         * out there too, in a directory nothing here made and nothing
         * here will only ever clean by name.  Nothing before this
         * asked the question, so there is no line anywhere relying on
         * the answer being "yes".
         *
         * A TESTSRC or a HEADERSRC arrives here as its SOURCES half,
         * so both refusals below name the command the line was
         * written as rather than the one it's being handled as, and
         * the example of a line that would be accepted is in that
         * command's shape too.  "SOURCES += main.c" is no fix for a
         * TESTSRC: it names no test at all, so taking the suggestion
         * as written quietly loses the test the line was there to
         * add. */
        {
            auto written = std::to_string(cmd->written_as());
            auto leaves = leaves_the_project(cmd->data());
            if (leaves.size() > 0) {
                auto example = std::string("main.c");
                if (cmd->written_as() == command_type::TESTSRC)
                    example = "boots.bash";
                else if (cmd->written_as() == command_type::HEADERSRC)
                    example = "main.h";

                std::cerr << std::to_string(cmd->debug()) << "\n"
                          << "  error: " << written << " names a file"
                          << " outside this project: " << leaves << "\n"
                          << "  write it inside the project, like '"
                          << written << " += " << example << "'\n";
                abort();
            }

            /* After the escape check above, for the same reason
             * LIBDIR asks after its own: a value with both a '$' and
             * a '(' keeps the more specific "make expansion"
             * answer. */
            refuse_unsafe_metacharacter(cmd, written);
        }

        /* From here on the file is called by the path it names rather
         * than by the text that named it.  The question above was
         * already answered of the normalized path, so this only makes
         * the answer and the use agree: a source is pasted onto the
         * object directory to name its object and onto the source
         * directory to name its compile line, and either one done with
         * the text as written gave "main.c" and "./main.c" an object
         * each -- one function linked twice -- and handed the kernel
         * "src/gone/../main.c", which it resolves a component at a
         * time and so refuses for want of a "gone" that the check
         * above had taken back off without looking.  One name per file
         * is also what lets two lines naming the same file be one
         * source, the way two lines spelling it the same already
         * were.
         *
         * Normalized only after both checks, since normalizing can
         * take apart exactly what they look for: "$(X)/../main.c" is
         * just "main.c" once the ".." has eaten the expansion. */
        auto source = cmd->with_data(file_utils::normalize_path(cmd->data()));

        clear_until({context_type::DEFAULT,
                    context_type::GENERATE,
                    context_type::LIBRARY,
                    context_type::BINARY,
                    context_type::TEST,
                    context_type::HEADER,}, cmd);

        /* A source file has to be compiled into something, and the
         * something is whatever target is open above it.  With
         * nothing open the context this hangs off is the project's
         * own, which is never asked for its targets and never asks
         * its children for theirs -- so the file is read, remembered,
         * and then dropped without a word. */
        if (_stack.top()->check_type({context_type::DEFAULT}) == true)
            _stack.top()->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                "SOURCES with no target open above it is dropped: nothing"
                " is being built out of this file",
                "put the BINARIES, LIBRARIES, LIBEXECS, TESTEXECS or"
                " HEADERS it belongs to above it, and check that nothing"
                " in between -- a SRCDIR or a LIBDIR -- closed that"
                " target first");

        /* A test source gets read for what it has to say about
         * itself, which is where a test's own dependencies are
         * written.  This is done here rather than after the push
         * because what it says lands on the test: a SOURCE is a copy
         * of the test's context that nothing ever asks for a check
         * target. */
        if (_stack.top()->check_type({context_type::TEST}) == true)
            process_directives(_stack.top()->src_dir + "/" + source->data());

        dup_tos_and_push(context_type::SOURCE, source);

        set_opts_target(_stack.top());

        return;
    }

    case command_type::SRCDIR:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT}, cmd);

        /* The same question as the LIBDIR above, with the same answer
         * about what the line means and a different one about what to
         * do -- and the difference is the whole of why that one is a
         * refusal and this one isn't.  A source directory is read
         * rather than removed: nothing pastes it into an "rm -rf", so
         * the worst this does is compile a file from outside the
         * project and write its object out there beside somebody
         * else's tree, since an object's path is its source's pasted
         * onto the object directory.  A line that quietly does
         * something nobody meant and takes nothing with it is exactly
         * what strict.h++ says to warn about and let through. */
        auto leaves = leaves_the_project(cmd->data());
        if (leaves.size() > 0)
            _stack.top()->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                "SRCDIR names a directory outside this project: " + leaves,
                "write it inside the project, like 'SRCDIR = src' -- an"
                " object is named by pasting its source's path onto the"
                " object directory, so a source read from out there is"
                " built into a directory out there too");

        /* After the warning above, for the same reason LIBDIR asks
         * after its own refusal: a value with both a '$' and a '('
         * keeps the more specific "make expansion" answer. */
        refuse_unsafe_metacharacter(cmd, "SRCDIR");

        _stack.top()->src_dir = _base + cmd->data();
        return;
    }

    /* How much of what pconfigure used to let a project get away with
     * it should still let this one get away with.  This lands on
     * whatever context is open, the same way a CROSS_COMPILE does,
     * which is what lets a subproject be stricter than the project
     * that pulled it in -- but the place to write it is the top of a
     * Configfile, since a warning is about a line rather than about a
     * target and the line might be anywhere. */
    case command_type::STRICT:
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        _stack.top()->strictness = strict::parse(cmd->data(), cmd->debug());

        return;

    case command_type::SUBPROJECTS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        refuse_unsafe_metacharacter(cmd, "SUBPROJECTS");

        /* An absolute path is asked about on the text as written,
         * before this project's base goes on the front, because
         * gluing the base on is what hides it.  At the top the base
         * is empty and "/home/me/src/a" sails through to be written
         * into the Makefile's include line and variable names, which
         * is this machine's checkout and nobody else's.  Inside a
         * subproject "a/" + "/b" normalizes to "a/b", so the line
         * quietly means a directory of a's from above and the root
         * of the filesystem's "b" from inside "a".  Neither reading
         * is a directory relative to the Configfile, which is what a
         * SUBPROJECTS is documented to name.
         *
         * Only this one spelling is taken from leaves_the_project()'s
         * list.  Climbing out is still judged against the resolved
         * path below, and deliberately so: a wrapper project whose
         * Configfile says "SUBPROJECTS += ../tree" about a tree
         * checked out beside it is how a vendored build gets wrapped,
         * and from the top that names a directory the top owns. */
        if (cmd->data().size() > 0 && cmd->data()[0] == '/') {
            std::cerr << "SUBPROJECTS can't name an absolute path: '"
                      << std::to_string(cmd->debug())
                      << "'\n"
                      << "  an absolute path names the same directory"
                      << " however this project is read, so the"
                      << " Makefile written from it only works in this"
                      << " checkout on this machine -- and inside a"
                      << " subproject it is read as relative to that"
                      << " subproject instead\n"
                      << "  write it relative to the Configfile that"
                      << " names it, like 'SUBPROJECTS += vendor/sub'\n";
            abort();
        }

        clear_until({context_type::DEFAULT}, cmd);

        /* A project that moved its source root can't also root
         * subprojects: a subproject's sources and its build output
         * would stop being in the same place, and one variable can't
         * mean both. */
        auto rooted_at = _base.size() == 0
            ? std::string(".")
            : _base.substr(0, _base.size() - 1);
        if (_srcpath != rooted_at) {
            std::cerr << "SUBPROJECTS doesn't work alongside SRCPATH: '"
                      << std::to_string(cmd->debug())
                      << "' is rooted at '" << _srcpath << "'\n";
            abort();
        }

        auto path = file_utils::normalize_directory(_base + cmd->data());

        if (path == _base) {
            std::cerr << "SUBPROJECTS can't point at the project itself: '"
                      << std::to_string(cmd->debug())
                      << "'\n";
            abort();
        }

        /* A directory that contains this project is the same mistake
         * one step removed: "SUBPROJECTS += .." in "a" names the
         * project that pulled "a" in, and a subproject that pulls its
         * own parent back in is a cycle.  Neither later step says so.
         * The top resolves to the empty path, which is also how the
         * loop that reads subprojects knows it has run out, so the
         * line was dropped without a word.  An ancestor that is
         * already a project was skipped as a tree asked for twice,
         * and one that is not -- the top naming "a/b" directly, with
         * ".." in "a/b" -- would be read as a project wrapped around
         * the one that named it.  Run inside the containing
         * directory, the same ".." climbs out and is refused, so from
         * above it is refused as well.  The message says only that
         * the directory contains this one, since whether it is a
         * project in this run depends on the lines above.
         *
         * Both paths are normalized directories ending in '/', or
         * empty for the top, so a prefix test can't mistake "ab/"
         * for being inside "a/". */
        if (_base.compare(0, path.size(), path) == 0
            && path.size() < _base.size()) {
            std::cerr << "SUBPROJECTS can't point at a directory that"
                      << " contains it: '"
                      << std::to_string(cmd->debug())
                      << "'\n"
                      << "  '" << cmd->data() << "' resolves to '"
                      << (path.size() == 0 ? std::string(".") : path)
                      << "', which contains this project's"
                      << " directory, so it can't also be its"
                      << " subproject\n"
                      << "  remove the line; a project reads its own"
                      << " subprojects, never the one above it\n";
            abort();
        }

        /* Everything here names files relative to where pconfigure
         * ran, and a Makefile written outside that tree would be
         * talking about a directory this build doesn't own.
         *
         * Which project that is depends on where pconfigure ran, and
         * this is the one rule here that is asked of the resolved
         * path on purpose.  A wrapper's "../tree" names the top's
         * "tree" when the top is read, which is fine, and names a
         * directory beside the checkout when pconfigure is run inside
         * the wrapper, which isn't.  So the same line is accepted
         * from above and refused from inside, and the refusal says
         * which project it was judged against and where to run
         * pconfigure instead, since "outside the project" alone reads
         * as a complaint about a line that works everywhere else. */
        if (path.compare(0, 3, "../") == 0) {
            std::cerr << "SUBPROJECTS can't reach outside the project: '"
                      << std::to_string(cmd->debug())
                      << "'\n"
                      << "  '" << cmd->data() << "' resolves to '"
                      << path << "', which climbs out of the project"
                      << " pconfigure was run in\n"
                      << "  a SUBPROJECTS may name a directory anywhere"
                      << " under the top of the run, so if this"
                      << " Configfile belongs to a subproject whose tree"
                      << " sits beside it, run pconfigure from the project"
                      << " that has both; otherwise check the tree out"
                      << " under this one, like 'SUBPROJECTS +="
                      << " vendor/sub'\n";
            abort();
        }

        refuse_unsafe_subproject_location(cmd, path,
                                          _stack.top()->obj_dir);

        /* The object directory is the one output directory a line
         * can be checked against as it's read, because nothing moves
         * it.  The rest of what "make distclean" removes -- where
         * binaries, libraries and test results go -- can still change
         * after this line, so whether the tree is under one of those
         * is asked once the whole run has been read; see
         * project::check_distclean_spares_subprojects(). */
        _named_subprojects.push_back(std::make_pair(path, cmd));

        /* Which build system builds it is decided by what's in it,
         * the same way the language that builds a source file is
         * decided by what the file is called.  Nothing has to be said
         * about the subproject from inside the subproject, which is
         * the point: a vendored tree is somebody else's and shouldn't
         * have to carry a file that says it's ours.
         *
         * pconfigure gets asked first, since a tree that says how to
         * build itself the pconfigure way meant it. */
        auto picked = build_system::ptr(NULL);
        for (const auto& available: _build_systems) {
            if (available->can_build(path) == false)
                continue;
            picked = available;
            break;
        }

        if (picked == NULL) {
            std::cerr << "Unable to find a build system for '"
                      << path
                      << "'\n  from '"
                      << std::to_string(cmd->debug())
                      << "'\n"
                      << "Build System Set:\n";
            for (const auto& available: _build_systems)
                std::cerr << "  " << available->name() << "\n";
            abort();
        }

        /* A tree that two Configfiles both ask for is one tree, and
         * only gets built once. */
        for (const auto& bound: _vendored) {
            if (bound->base() != path)
                continue;
            _configure_target = bound;
            return;
        }

        /* Binding copies, so that the CONFIGUREOPTS that come after
         * this land on this subproject rather than on every other
         * subproject built the same way. */
        auto bound = picked->bind(path, _stack.top());
        _configure_target = bound;

        if (picked->vendored() == false) {
            /* Reading it is somebody else's job: this just says which
             * one was asked for, relative to where pconfigure is
             * running rather than to whoever asked. */
            _pending_subprojects.push_back({path, cmd});
            return;
        }

        /* Two trees that build into the same directory would each
         * be running somebody else's build system over the other
         * one's output, and neither of them would say so: the tree
         * whose turn came second would just find files it didn't put
         * there.  The names are short enough now to collide, which is
         * the price of their being short -- what the directory is
         * called is the subproject with the source directory taken
         * off, so "src/linux" and "linux" are one name written two
         * ways. */
        for (const auto& already: _vendored) {
            if (already->output_dir() != bound->output_dir())
                continue;

            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: this builds into '"
                      << bound->output_dir() << "', and so does '"
                      << already->source_dir() << "'\n"
                      << "  an output directory is named after the tree"
                      << " with the source directory taken off the"
                      << " front,\n"
                      << "  so two trees whose paths differ only by that"
                      << " ask for the same directory\n"
                      << "  move or rename one of them: a vendored tree's"
                      << " output is the tree's alone\n";
            abort();
        }

        _vendored.push_back(bound);

        return;
    }

    /* Something that has to be built before this target's tests are
     * run.  This is DEPLIBS' opposite number for the test side, and
     * it takes a whole path rather than a library name because what a
     * test wants first is usually a program rather than a library --
     * and there's no short name that covers everything a test could
     * possibly need. */
    case command_type::TESTDEPS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        if (_stack.top()->check_type({context_type::BINARY,
                                      context_type::LIBRARY,
                                      context_type::GENERATE,
                                      context_type::PHONY,
                                      context_type::TEST,}) == false) {
            std::cerr << "Attempted to add TESTDEPS to a "
                      << std::to_string(_stack.top()->type)
                      << " context, which isn't supported"
                      << "\n";
            abort();
        }

        /* A project doesn't get to name anything outside itself.
         * The question is asked of the path alone rather than of the
         * path this project happens to sit at, so that it has the
         * same answer whether this project is being built on its own
         * or as part of something bigger -- a rule that changed with
         * where make was run would be no rule at all.
         *
         * What a test in one project needs from another is a
         * dependency of the build rather than of the test, and it
         * goes on the link line where every other cross-project
         * dependency goes -- through "ppkg-config", usually.  A test
         * that really is about two projects at once is an
         * integration test and belongs to the project that has both
         * of them, where the path to either one is an ordinary path
         * that doesn't leave the tree.
         *
         * Which spellings leave it is leaves_the_project()'s answer
         * rather than one written out here, so that a TESTDEPS is
         * refused for exactly what a LIBDIR is refused for.  Asking
         * it in its own words is how the bare ".." got in: a check
         * written as "starts with '../'" has nothing to match against
         * on a path with no trailing slash, so "TESTDEPS += .." went
         * past and came out as a prerequisite naming the directory
         * this project was checked out into. */
        auto named = file_utils::normalize_path(cmd->data());
        auto leaves = leaves_the_project(cmd->data());
        if (leaves.size() > 0) {
            std::cerr << "TESTDEPS can't reach outside the project: '"
                      << std::to_string(cmd->debug())
                      << "'\n"
                      << "  " << leaves << "\n"
                      << "  a test that needs something another project"
                      << " builds wants it on the link line,\n"
                      << "  and a test that's about both of them belongs to"
                      << " whoever has both of them\n";
            abort();
        }

        /* After the escape check above, for the same reason LIBDIR
         * asks after its own: a value with both a '$' and a '(' keeps
         * the more specific "make expansion" answer. */
        refuse_unsafe_metacharacter(cmd, "TESTDEPS");

        /* A file a vendored tree was said to produce is spelled from
         * the object directory that tree builds into, rather than
         * from the project the way everything else here is.
         *
         * The object directory is on the front of every one of those
         * paths and so tells none of them apart: what it adds to the
         * line is the answer to a question -- where does this
         * project keep build output -- that the line wasn't asking.
         * The tree's name is the part that was being said, and a
         * TESTDEPS gets to say only that.
         *
         * Only a file the tree was said to produce is read this way.
         * Everything else keeps meaning what it always meant, so a
         * project with a directory of its own named after one of its
         * vendored trees still reaches its own. */
        auto in_obj = _stack.top()->unbased(_stack.top()->obj_dir)
                    + "/" + named;
        for (const auto& vendored: _vendored) {
            if (vendored->produces(_stack.top()->base + in_obj) == false)
                continue;

            _stack.top()->test_deps.push_back(in_obj);
            return;
        }

        _plain_test_deps.push_back({cmd, _stack.top()->base + in_obj});
        _stack.top()->test_deps.push_back(cmd->data());

        return;
    }

    /* One test waiting on another one, which is the only way to say
     * that two tests share something expensive to produce: the first
     * one makes it and the second one reads what the first one left
     * behind.  What gets handed along is between the two tests -- all
     * this does is put them in an order and run the second one again
     * whenever the first one runs. */
    case command_type::DEPTESTS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        refuse_unsafe_metacharacter(cmd, "DEPTESTS");

        /* This lands on one test rather than on a target, which is
         * what makes it different from every other DEP- and -DEPS
         * command.  A target-wide one would be read by every test
         * underneath, including the test it names -- so the thing it
         * asked for would be that test waiting for itself, which is
         * not an order anything could run in.  The waiting is a
         * property of the one test that does it. */
        auto test = enclosing_test();
        if (test == NULL) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: "
                      << std::to_string(cmd->type())
                      << " with no test open above it has nothing that"
                      << " could wait\n"
                      << "  put it directly under the TESTS or TESTSRC"
                      << " line of the test that does the waiting\n"
                      << "  it can't go on the target the way a TESTDEPS"
                      << " does: every test under the target would read"
                      << " it,\n"
                      << "  and one of those tests is the one being"
                      << " waited for\n";
            abort();
        }

        /* A DEPTESTS names a test of the same target and nothing
         * else: it is the bare name off that test's own TESTS line,
         * so a path that climbs out of the check directory is
         * reaching for somebody else's test.
         *
         * The tests under one target are one suite, and whatever they
         * hand between themselves is that suite's business.  Two
         * tests under different targets that share state aren't two
         * suites either -- they're one, and it belongs to whoever has
         * both of them, which is what a PHONY is for.  Ordering them
         * across targets instead would be an order that only holds
         * when one make happens to build both, which is no order at
         * all.
         *
         * Which spellings reach out of it is leaves_the_project()'s
         * answer, the same one a TESTDEPS gets, and for the same
         * reason: a check written here in its own words was a check
         * that let the bare ".." through.  That one was caught
         * further down, by the rule that a DEPTESTS names a test this
         * target actually has -- but caught there it is reported as a
         * missing test rather than as a path that left the project,
         * which sends whoever reads it looking for the wrong thing. */
        auto leaves = leaves_the_project(cmd->data());
        if (leaves.size() > 0) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: DEPTESTS can't reach outside the"
                      << " target\n"
                      << "  " << leaves << "\n"
                      << "  it names a test of this same target, spelled"
                      << " the way that test's own TESTS line spelled"
                      << " it\n"
                      << "  two tests under different targets that share"
                      << " state are one suite: put both under a PHONY\n";
            abort();
        }

        test->dep_tests.push_back(cmd->data());

        return;
    }

    /* The sets this project's tests are divided into.  A project with
     * tests that can't be run everywhere -- the ones that want a
     * network, or a card, or an hour -- has nowhere to say so while
     * there is only one set of them: whatever "make check" means has
     * to mean the same thing on every machine it gets run on.  A
     * suite is a name for some of the tests, and a project gets as
     * many of them as it has answers to "which tests can this machine
     * run".
     *
     * The line only declares the name.  Which tests are in the suite
     * is said by the tests, so a suite that nothing joined is empty
     * rather than wrong: it's a promise about what "make check-<name>"
     * means, kept by a run with nothing to do. */
    case command_type::TEST_SUITES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT}, cmd);

        if (names_a_suite(cmd->data()) == false) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: '" << cmd->data() << "' is not a name a"
                      << " test suite can have\n"
                      << "  the name is what the suite's make targets are"
                      << " called, so it holds letters, digits, '-', '_'"
                      << " and '.' and nothing else\n"
                      << "  name the suite after the thing its tests need,"
                      << " the way a target is named after what it"
                      << " builds\n";
            abort();
        }

        /* Naming one that's already here is how you get back to it to
         * say something more about it, which is exactly what a second
         * BUILD_SYSTEMS line does. */
        for (const auto& existing: _test_suites) {
            if (existing->name() != cmd->data())
                continue;
            _test_suite_target = existing;
            return;
        }

        auto added = std::make_shared<test_suite>(cmd->data(), cmd);
        _test_suites.push_back(added);
        _test_suite_target = added;

        return;
    }

    /* Which suite "make check" means.  A project that has a set of
     * tests every machine can run wants that set to be what happens
     * when somebody types the two words they already know, rather
     * than something they have to be told about -- and the tests that
     * only some machines can run are exactly the ones a stranger to
     * the project shouldn't be handed by default.
     *
     * With nothing said "make check" means every test, which is what
     * it has always meant. */
    case command_type::DEFAULT_TEST_SUITE:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT}, cmd);

        _default_test_suite = cmd->data();
        _default_test_suite_cmd = cmd;

        return;
    }

    /* One suite running another's tests along with its own.  Two
     * machines that can run overlapping sets of tests is the ordinary
     * case -- the machine with the network can also run everything
     * the machine without it can -- and writing that down as
     * membership would mean naming every test twice.
     *
     * This says nothing about order and nothing about when anything
     * runs: the tests of the included suite are the same tests, run
     * once, reported under both names.  Making one test wait for
     * another is what a DEPTESTS is for. */
    case command_type::INCLUDE_TEST_SUITES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        if (_test_suite_target == NULL) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: "
                      << std::to_string(cmd->type())
                      << " with no test suite open above it has nothing"
                      << " to include anything into\n"
                      << "  put it directly under the TEST_SUITES line of"
                      << " the suite that does the including\n";
            abort();
        }

        _test_suite_target->add_include(cmd);

        return;
    }

    case command_type::TESTS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT,
                    context_type::GENERATE,
                    context_type::LIBRARY,
                    context_type::BINARY,
                    context_type::HEADER,
                    context_type::PHONY,}, cmd);
        auto parent = _stack.top();

        /* A test belongs to the thing it exercises, and with nothing
         * open the parent is the project's own context, which has no
         * command behind it -- so what used to happen here was a null
         * dereference and a signal, with nothing printed at all.
         * That makes this an error rather than a warning: there is no
         * behaviour to stay compatible with. */
        if (parent->cmd == NULL) {
            std::cerr << std::to_string(cmd->debug()) << "\n"
                      << "  error: "
                      << std::to_string(cmd->type())
                      << " with no target open above it has nothing to"
                      << " test\n"
                      << "  put it under the BINARIES, LIBRARIES, LIBEXECS"
                      << " or TESTEXECS whose tests these are,\n"
                      << "  or under a PHONY if what it exercises isn't any"
                      << " one thing this project builds\n";
            abort();
        }

        dup_tos_and_push(context_type::TEST, cmd);
        auto child = _stack.top();
        child->src_dir = parent->test_dir + "/" + parent->cmd->data();
        child->check_dir = parent->check_dir + "/" + parent->cmd->data();

        /* Which suite this test is in, or empty for a test that was
         * written without a name in brackets.  Whether the suite
         * exists is not asked here: a project's suites are a set, and
         * a test is allowed to join one that a later line declares. */
        child->test_suite_name = cmd->qualifier();

        set_opts_target(_stack.top());

        return;
    }

    /* A test named by its source, which is the source's path -- so the
     * test is named by the path that file actually has, the same one
     * its SOURCES half settles on, or "t.bash" and "./t.bash" are two
     * check rules for one tarball and make runs the test twice into
     * it.  The SOURCES half is handed the line as written, since it is
     * the half that asks whether the path is one this project may
     * name, and it has to ask that of the text normalizing would have
     * tidied the answer out of. */
    case command_type::TESTSRC:
    {
        auto named = file_utils::normalize_path(cmd->data());
        process_one(cmd->with_data(named)->with_type(command_type::TESTS));
        process_one(cmd->with_type(command_type::SOURCES));
        return;
    }

    /* These two look like they take a value and don't: writing one
     * at all turns the thing on, and "= false" turns it on just as
     * surely as "= true" does.  Leaving that quiet is how a project
     * ends up with a Configfile that says the opposite of what the
     * build does. */
    case command_type::VERBOSE:
    case command_type::DEBUG:
        if (cmd->check_operation("=") == false || cmd->data() != "true")
            _stack.top()->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                std::to_string(cmd->type()) + " ignores what it's set to:"
                " writing the line at all turns it on, and it stays on for"
                " everything below",
                "write '" + std::to_string(cmd->type()) + " = true' when"
                " that's what's wanted, and leave the line out entirely"
                " when it isn't");

        if (cmd->type() == command_type::VERBOSE)
            _stack.top()->verbose = true;
        else
            _stack.top()->debug = true;

        return;

    case command_type::VERSION:
        this->_given_version_command = true;
        return;

    case command_type::HELP:
        this->_given_help_command = true;
        return;

    case command_type::SRCPATH:
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

    {
        /* A SRCPATH is relative to the project it shows up in, which
         * is only the directory pconfigure was run from for the
         * top-level project. */
        /* This rewrites the source directories in place rather than
         * replacing them, so a second one is read relative to
         * whatever the first one already produced: "SRCPATH = a" then
         * "SRCPATH = b" looks under "b/a".  It's written with an '='
         * rather than a '+=', which is a promise that it replaces. */
        if (_given_srcpath == true)
            tos->strictness.complain(
                strict_since::v0_13(),
                cmd->debug(),
                "a second SRCPATH doesn't replace the first one, it's read"
                " relative to it",
                "say it once, at the top of the project, and remember that"
                " '--srcpath' on the command line has already said it");
        _given_srcpath = true;

        auto path = _base + cmd->data();
        tos->src_dir = path + "/" + tos->src_dir.substr(_base.size());
        tos->test_dir = path + "/" + tos->test_dir.substr(_base.size());
        tos->src_path = path + "/";
        _srcpath = path;
        return;
    }

    case command_type::HEADERSRC:
        process_one(cmd->with_type(command_type::HEADERS));
        process_one(cmd->with_type(command_type::SOURCES));
        return;

    case command_type::PHC:
        _stack.top()->phc = cmd->data();
        return;
    }

    std::cerr << "Bad command index on '"
              << std::to_string(cmd->debug())
              << "'\n";
    abort();

/* A command the parser knows the name of and nothing here does
 * anything with.  It is still a fatal error like any other, so it
 * says which line asked for it: in a tree with several Configfiles,
 * the name of the command alone leaves whoever reads this grepping
 * for it.  There is nothing to write instead that would do the same
 * thing -- if there were, the command would be implemented as that
 * -- so the advice is the one thing that gets past it. */
unimplemented:
    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: "
              << std::to_string(cmd->type())
              << " is accepted by the parser but not implemented\n"
              << "  remove the line; this version of pconfigure does"
              << " nothing with it\n";
    abort();

bad_op_eq:
    refuse_operator(cmd, "=");
    abort();

bad_op_pluseq:
    refuse_operator(cmd, "+=");
    abort();

no_opts_target:
    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: Command "
              << std::to_string(cmd->type())
              << " needs an *OPTS target, but none exists\n"
              << "  a " << std::to_string(cmd->type())
              << " lands on whatever was opened last above it -- a"
              << " LANGUAGES, for every file in that language, or a"
              << " target such as a BINARIES, LIBRARIES or SOURCES, for"
              << " that one alone -- and"
              << " nothing above this line opened any of them\n"
              << "  write it below the LANGUAGES, BINARIES or LIBRARIES"
              << " line it is meant for\n";
    abort();

no_configure_target:
    std::cerr << std::to_string(cmd->debug()) << "\n"
              << "  error: Command "
              << std::to_string(cmd->type())
              << " needs a BUILD_SYSTEMS target, but none exists\n"
              << "  a " << std::to_string(cmd->type())
              << " is for a tree some other build system builds: it"
              << " lands on the BUILD_SYSTEMS or vendored SUBPROJECTS"
              << " opened last above it, and nothing above this line"
              << " opened one\n"
              << "  write it below the BUILD_SYSTEMS or SUBPROJECTS line"
              << " it is meant for\n";
    abort();
}

test_suite::ptr
command_processor::test_suite_named(const std::string& name) const
{
    for (const auto& suite: _test_suites)
        if (suite->name() == name)
            return suite;

    return NULL;
}

std::string command_processor::take_pending_subproject(command::ptr& asked_by)
{
    if (_pending_subprojects.size() == 0)
        return "";

    auto out = _pending_subprojects.front().first;
    asked_by = _pending_subprojects.front().second;
    _pending_subprojects.erase(_pending_subprojects.begin());

    /* Whatever this tree is going to be told, it is being told now.
     * A line below this point that would have changed the answer is
     * changing it too late. */
    _read_a_subproject = true;
    return out;
}

command::ptr command_processor::take_pending_config(void)
{
    if (_pending_configs.size() == 0)
        return NULL;

    auto out = _pending_configs.front();
    _pending_configs.erase(_pending_configs.begin());
    return out;
}

std::string command_processor::take_pending_config_dep(void)
{
    if (_pending_config_deps.size() == 0)
        return "";

    auto out = _pending_config_deps.front();
    _pending_config_deps.erase(_pending_config_deps.begin());
    return out;
}

void command_processor::clear_until(const std::vector<context_type>& types,
                                    const command::ptr& by)
{
    /* A line that opens a target has left whatever suite was being
     * declared behind it, whether or not it pops anything: the
     * declaration is a top-level statement, and the only lines that
     * belong to it are the ones directly underneath. */
    _test_suite_target = NULL;

    while ((_stack.size() > 0) && (_stack.top()->check_type(types) == false)) {
        auto top = _stack.top();
        _stack.pop();
        _all_contexts.push_back(top);

        /* A popped context is kept forever -- it's in _all_contexts
         * now and it was in its parent's children already -- so this
         * pointer stays good and nothing else can ever be allocated
         * where it is.  That's why writing to a closed target has
         * always been quiet rather than a crash, and it's what makes
         * the identity test below trustworthy.
         *
         * Identity against what was popped, rather than "is
         * _opts_target the top of the stack": a GENERATE deliberately
         * pushes a source context on top of the target it just
         * pointed this at, so the two aren't the same there and
         * nothing is wrong. */
        if (_opts_target == top) {
            _stale_opts_target = top;
            _stale_opts_closed_by = by;
        }
    }

    if (_stack.size() == 0) {
        std::cerr << "Interal error: empty stack\n";
        abort();
    }
}

context::ptr command_processor::enclosing_test(void) const
{
    /* std::stack only shows its top, and what's wanted here is the
     * context under it -- so this walks a copy down rather than
     * taking the real one apart and putting it back. */
    auto rest = _stack;

    while (rest.empty() == false) {
        if (rest.top()->check_type({context_type::TEST}) == true)
            return rest.top();

        /* A source is the one thing that can sit between a DEPTESTS
         * and the test it belongs to, and it gets there because
         * TESTSRC opens one.  Anything else means the test was closed
         * before this line was reached, and a DEPTESTS that quietly
         * attached itself to whatever came next would be worse than
         * one that says nothing is open. */
        if (rest.top()->check_type({context_type::SOURCE}) == false)
            return NULL;

        rest.pop();
    }

    return NULL;
}

void command_processor::process_directives(const std::string& path)
{
    /* A TESTDEPS is read out of this file rather than out of a
     * Configfile, but it's the same kind of fact: a line here decides
     * what the Makefile says, so editing it has to be a reason to
     * write the Makefile again.  AUTORECONFIGURE only watches what
     * configfiles_read() names, and nothing else visits this path --
     * so without this, a "#pconfigure TESTDEPS" line added to a test
     * takes effect at the next pconfigure and not one edit sooner,
     * which for an AUTORECONFIGURE project is a plain "make" that
     * never runs it. */
    add_configfile_dep(path);

    pinclude::list(
        path,
        [](std::string) { return 0; },
        true,

        /* The strict reading of what counts as a directive: a '#' in
         * the first column with the word written against it.  A
         * "#pconfigure" is a line pconfigure reads rather than one
         * the compiler does, and that spelling is the one that means
         * the same thing whatever the test is written in -- it's what
         * a shell script has to use, since a '#' anywhere else on a
         * line of shell is a comment, and it's the only way a C file
         * could write one that its own compiler wouldn't choke on
         * first. */
        pinclude::syntax::SHELL,

        [&](const pinclude::directive& directive) {
            /* The directive can be reached through an "#include"
             * instead of sitting in "path" itself (see
             * testdeps-directive.bash's "includes-it.bash"), and it's
             * that file's edits a TESTDEPS on it has to survive --
             * same reason as the add_configfile_dep() above, one
             * level over. */
            add_configfile_dep(directive.filename);

            auto debug = std::make_shared<debug_info>(directive.filename,
                                                      directive.line_number,
                                                      directive.line);

            /* What to say about a TESTDEPS that wasn't written as
             * one, which is a thing two checks below both find: the
             * operator has to be there, and it has to be spaced out
             * from what's on either side of it.  A shell script's own
             * habits produce neither, since nothing else in a test
             * file spaces an '=' apart from anything. */
            auto not_a_command = [&]() {
                std::cerr << std::to_string(debug) << "\n"
                          << "  error: this isn't a command\n"
                          << "  write it as 'TESTDEPS += path', with"
                          << " the operator and the path spaced apart"
                          << " from each other and from the command\n";
                abort();
            };

            auto split = string_utils::split_char(directive.data, " ");
            if (split.size() == 0 || split[0].size() == 0) {
                std::cerr << std::to_string(debug) << "\n"
                          << "  error: this #pconfigure says nothing\n"
                          << "  a directive carries a command, and the"
                          << " only one a test can carry is a"
                          << " 'TESTDEPS += path' naming something that"
                          << " has to be built before the test runs\n";
                abort();
            }

            /* A name in brackets belongs to the command rather than
             * to this, so it comes off before working out which
             * command was written.  What to say about a command that
             * was handed a name it doesn't take is the same question
             * here as it is in a Configfile, and it's answered in the
             * same place. */
            auto name = split[0];
            auto open = name.find('[');
            if (open != std::string::npos)
                name = name.substr(0, open);

            auto type = [&]() {
                try {
                    return check_command_type(name);
                } catch (...) {
                    std::cerr << std::to_string(debug) << "\n"
                              << "  error: '" << name << "' is not a"
                              << " command\n"
                              << "  a '#pconfigure' written against the"
                              << " first column of a shell script is a"
                              << " directive rather than a comment\n"
                              << "  put a space after the '#' if this"
                              << " was meant to be one\n";
                    abort();
                }
            }();

            /* A TESTDEPS is the whole of what a test gets to say
             * about itself.  Everything else a Configfile can write
             * is about a target rather than about one of its tests,
             * so a directive is the wrong place to write it: what it
             * would land on is whichever test was open when the file
             * was read, which is this one and none of the others.
             *
             * The message names no other command that could go here,
             * because there isn't one yet.  A directive that says
             * something else about a test is a directive somebody has
             * a use for, and it can be let through when it turns
             * up. */
            if (type != command_type::TESTDEPS) {
                std::cerr << std::to_string(debug) << "\n"
                          << "  error: "
                          << std::to_string(type)
                          << " can't be written in a #pconfigure\n"
                          << "  a TESTDEPS is the whole of what a test"
                          << " gets to say about itself here: what has"
                          << " to be built before it runs\n"
                          << "  everything else goes in the Configfile,"
                          << " under the target it's about\n";
                abort();
            }

            if (split.size() < 3)
                not_a_command();

            /* Nothing above got this far without the command being a
             * TESTDEPS written with an operator and a value, which is
             * everything the parser could turn its nose up at -- so
             * this is here to keep a parser that grows a new opinion
             * from being answered with a null dereference. */
            auto cmd = command::parse(directive.data, debug);
            if (cmd == NULL)
                not_a_command();

            process(cmd);
        }
    );
}

void command_processor::dup_tos_and_push(const context_type& type,
                                         const command::ptr& cmd)
{
    auto nctx = _stack.top()->dup(type, cmd, {});
    _stack.top()->children.push_back(nctx);
    _stack.push(nctx);
}
