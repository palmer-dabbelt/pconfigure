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
#include <iostream>

command_processor::command_processor(const std::string& base,
                                     const context::ptr& defaults)
    : _stack(),
      _opts_target(NULL),
      _stale_opts_target(NULL),
      _stale_opts_closed_by(NULL),
      _build_systems(),
      _vendored(),
      _configure_target(NULL),
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
    case command_type::TESTDEPS:
    case command_type::TESTEXECS:
    case command_type::TESTS:
    case command_type::TESTSRC:
    case command_type::TGENERATE:
        return true;

    case command_type::AUTODEPS:
    case command_type::BUILD_SYSTEMS:
    case command_type::COMPAT:
    case command_type::COMPILEOPTS:
    case command_type::COMPILER:
    case command_type::CONFIG:
    case command_type::CONFIGUREOPTS:
    case command_type::CROSS_COMPILE:
    case command_type::DEBUG:
    case command_type::DEPLIBS:
    case command_type::HELP:
    case command_type::LANGUAGES:
    case command_type::LINKER:
    case command_type::LINKOPTS:
    case command_type::PHC:
    case command_type::STRICT:
    case command_type::VERBOSE:
    case command_type::VERSION:
        return false;
    }

    return false;
}

void command_processor::process(const command::ptr& cmd)
{
    /* Said here rather than inside the switch because TESTSRC and
     * HEADERSRC are each two commands wearing one hat and go through
     * process_one() twice: this is about the line as it was written,
     * and the line was written once. */
    if (names_a_path(cmd->type()) == true
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

    process_one(cmd);
}

void command_processor::process_one(const command::ptr& cmd)
{
    auto tos = _stack.top();

    switch (cmd->type()) {
    case command_type::AUTODEPS:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        if (cmd->data() == "true") {
            tos->autodeps = true;
            return;
        }

        if (cmd->data() == "false") {
            tos->autodeps = false;
            return;
        }

        std::cerr << cmd->data() << " is not boolean\n";
        abort();
        return;
    }

    case command_type::BINARIES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::BINARY, cmd);

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        auto ctx = _stack.top();
        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

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
        _pending_configs.push_back(cmd->data());

        return;
    }

    case command_type::CONFIGUREOPTS:
        if (_configure_target == NULL)
            goto no_configure_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        _configure_target->add_configureopt(cmd->data());

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
            std::cerr << "Attempted to add DEPLIB to a "
                      << std::to_string(_stack.top()->type)
                      << " context, which isn't supported"
                      << "\n";
            abort();
        }

        _stack.top()->dep_libs.push_back(cmd->data());

        return;

    /* What a binary is allowed to ask the kernel for.  This is only
     * ever consulted on macOS, but it's accepted everywhere: a
     * Configfile shouldn't have to know which machine is reading it,
     * and a platform with nothing to sign has nothing to do here. */
    case command_type::ENTITLEMENTS:
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        /* Only a whole linked thing is ever signed, so an
         * ENTITLEMENTS that landed below one is asking for nothing --
         * and asking for nothing quietly is worse here than
         * elsewhere, since what comes out is a binary that runs until
         * it reaches the thing it wasn't allowed to do. */
        if (tos->check_type({context_type::SOURCE,
                             context_type::HEADER,
                             context_type::GENERATE,
                             context_type::TEST,}) == true)
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

    case command_type::GENERATE:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::GENERATE, cmd);

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        dup_tos_and_push(context_type::SOURCE,
                         std::make_shared<command>(
                             cmd->type(),
                             "+=",
                             cmd->data() + ".proc",
                             cmd->debug()
                             )
            );

        return;

    case command_type::HDRDIR:
        goto unimplemented;

    case command_type::HEADERS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

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
            std::cerr << "Unable to find language: '"
                      << cmd->data()
                      << "'\n";
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
        _stack.top()->lib_dir = _base + cmd->data();
        return;
    }

    case command_type::LIBEXECS:
    case command_type::TESTEXECS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

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

        clear_until({context_type::DEFAULT}, cmd);
        dup_tos_and_push(context_type::LIBRARY, cmd);

        set_opts_target(_stack.top());
        _output_contexts.push_back(_stack.top());

        auto ctx = _stack.top();
        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

        return;
    }

    case command_type::LINKER:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        check_opts_target(cmd);
        _opts_target->set_linker(cmd->data());

        return;

    case command_type::LINKOPTS:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

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

        _opts_target->add_linkopt(cmd->data());

        return;

    case command_type::PREFIX:
        if (cmd->check_operation("=") != true)
            goto bad_op_eq;

        tos->prefix = cmd->data();

        return;

    case command_type::SOURCES:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

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

        dup_tos_and_push(context_type::SOURCE, cmd);

        set_opts_target(_stack.top());

        return;

    case command_type::SRCDIR:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT}, cmd);
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

        /* Everything here names files relative to where pconfigure
         * ran, and a Makefile written outside that tree would be
         * talking about a directory this build doesn't own. */
        if (path.compare(0, 3, "../") == 0) {
            std::cerr << "SUBPROJECTS can't reach outside the project: '"
                      << std::to_string(cmd->debug())
                      << "'\n";
            abort();
        }

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
            _pending_subprojects.push_back(path);
            return;
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
         * that doesn't leave the tree. */
        auto named = file_utils::normalize_path(cmd->data());
        if (named.compare(0, 3, "../") == 0
            || (named.size() > 0 && named[0] == '/')) {
            std::cerr << "TESTDEPS can't reach outside the project: '"
                      << std::to_string(cmd->debug())
                      << "'\n"
                      << "  a test that needs something another project"
                      << " builds wants it on the link line,\n"
                      << "  and a test that's about both of them belongs to"
                      << " whoever has both of them\n";
            abort();
        }

        _stack.top()->test_deps.push_back(cmd->data());

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
                    context_type::HEADER,}, cmd);
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
                      << " or TESTEXECS whose tests these are\n";
            abort();
        }

        dup_tos_and_push(context_type::TEST, cmd);
        auto child = _stack.top();
        child->src_dir = parent->test_dir + "/" + parent->cmd->data();
        child->check_dir = parent->check_dir + "/" + parent->cmd->data();

        set_opts_target(_stack.top());

        return;
    }

    case command_type::TESTSRC:
        process_one(cmd->with_type(command_type::TESTS));
        process_one(cmd->with_type(command_type::SOURCES));
        return;

    case command_type::TGENERATE:
        unimplemented:
        std::cerr << "Command "
                  << std::to_string(cmd->type())
                  << " not implemented\n";
        abort();
        break;

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

bad_op_eq:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " only supports '=', but given "
              << cmd->operation()
              << "\n";
    abort();

bad_op_pluseq:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " only supports '+=', but given "
              << cmd->operation()
              << "\n";
    abort();

no_opts_target:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " needs an *OPTS target, but none exists\n";
    abort();

no_configure_target:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " needs a BUILD_SYSTEMS target, but none exists\n";
    abort();
}

std::string command_processor::take_pending_subproject(void)
{
    if (_pending_subprojects.size() == 0)
        return "";

    auto out = _pending_subprojects.front();
    _pending_subprojects.erase(_pending_subprojects.begin());
    return out;
}

std::string command_processor::take_pending_config(void)
{
    if (_pending_configs.size() == 0)
        return "";

    auto out = _pending_configs.front();
    _pending_configs.erase(_pending_configs.begin());
    return out;
}

void command_processor::clear_until(const std::vector<context_type>& types,
                                    const command::ptr& by)
{
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

void command_processor::dup_tos_and_push(const context_type& type,
                                         const command::ptr& cmd)
{
    auto nctx = _stack.top()->dup(type, cmd, {});
    _stack.top()->children.push_back(nctx);
    _stack.push(nctx);
}
