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

#ifndef COMMAND_PROCESSOR_HXX
#define COMMAND_PROCESSOR_HXX

#include <memory>
#include <stack>
#include "build_system.h++"
#include "command.h++"
#include "context.h++"
#include "language_list.h++"
#include "opts_target.h++"
#include "test_suite.h++"

/* Contains the entire state of the build system.  This processes a
 * list of commands and converts it into a graph of dependencies that
 * can then be fully flushed out in order to produce a proper list of
 * targets. */
class command_processor {
public:
    typedef std::shared_ptr<command_processor> ptr;

private:
    /* This is the stack that's visible to the user of pconfigure. */
    std::stack<context::ptr> _stack;

    /* The object that should be touched for {COMPILE,LINK}OPTS. */
    opts_target::ptr _opts_target;

    /* The target above, once whatever opened it has been closed by a
     * command that went back to the top of the project without
     * opening anything new.  A COMPILER or a COMPILEOPTS written
     * after one of those still lands on it, which is almost never
     * what the line meant -- so it's remembered here, along with the
     * command that closed it, to say so. */
    context::ptr _stale_opts_target;
    command::ptr _stale_opts_closed_by;

    /* The build systems that are available to build a SUBPROJECTS,
     * which is pconfigure plus whatever a BUILD_SYSTEMS asked for.
     * None of these is bound to a directory: they're the list that a
     * SUBPROJECTS gets matched against. */
    std::vector<build_system::ptr> _build_systems;

    /* The third-party trees this project pulled in, one per
     * SUBPROJECTS that turned out not to be a pconfigure project.
     * These are bound, and they're what produce targets. */
    std::vector<build_system::ptr> _vendored;

    /* The object that should be touched for CONFIGUREOPTS, which is
     * whichever build system or subproject was named most
     * recently. */
    build_system::ptr _configure_target;

    /* The sets this project's tests are divided into, in the order
     * they were declared -- which is the order their rules come out
     * in, so it has to be stable. */
    std::vector<test_suite::ptr> _test_suites;

    /* The suite that "make check" runs, as a DEFAULT_TEST_SUITE named
     * it, or empty when nothing said and "make check" means every
     * test the project has.  The command is kept alongside it because
     * a complaint about the name has to point at the line. */
    std::string _default_test_suite;
    command::ptr _default_test_suite_cmd;

    /* The suite that an INCLUDE_TEST_SUITES lands on, which is
     * whichever one a TEST_SUITES named most recently.  It's dropped
     * whenever a line opens a target, so a subcommand that ended up
     * somewhere else is a subcommand with nothing above it rather
     * than one that quietly joined a suite from further up the
     * file. */
    test_suite::ptr _test_suite_target;

    /* Every TESTDEPS that was read as a path in the project, with the
     * path it would have been read as had it named a file some
     * vendored tree was already said to produce.
     *
     * A Configfile is read top to bottom and a TESTDEPS is resolved
     * where it's written, so one written above the SUBPROJECT_TARGETS
     * that claims it means the other thing.  This is what a later
     * SUBPROJECT_TARGETS checks itself against, so that the answer
     * doesn't quietly depend on which of the two lines came first. */
    struct plain_test_dep {
        command::ptr cmd;
        std::string in_obj;
    };
    std::vector<plain_test_dep> _plain_test_deps;

    /* A list of every target that's ever been part of the context
     * stack. */
    std::vector<context::ptr> _all_contexts;

    /* A list of every target that needs to be output explicitly. */
    std::vector<context::ptr> _output_contexts;

    /* This is set to TRUE if a "--version" command was given. */
    bool _given_version_command;

    /* This is set to TRUE if a "--help" command was given. */
    bool _given_help_command;

    /* TRUE once a SRCPATH has moved this project's source root,
     * which is worth knowing because a second one is read relative to
     * the first rather than replacing it. */
    bool _given_srcpath;

    /* The path that this project's Configfiles are read from, which
     * is changed by the SRCPATH command. */
    std::string _srcpath;

    /* The directory this project is rooted at, which is either empty
     * or ends with a '/'. */
    const std::string _base;

    /* The context at the bottom of the stack, which holds this
     * project's defaults. */
    context::ptr _root;

    /* The subprojects that have been asked for but not read yet.
     * They're handed back one at a time rather than read here,
     * because reading a project is the job of whoever owns this. */
    std::vector<std::string> _pending_subprojects;

    /* The Configfiles a CONFIG command asked for, which are handed
     * back the same way and for the same reason. */
    std::vector<std::string> _pending_configs;

public:
    /* Creates a new, mostly empty command processor (there is a
     * default context on the stack, for example) for the project
     * rooted at "base" -- which is either empty, for the project
     * being configured, or a path ending in '/' for a subproject. */
    command_processor(const std::string& base = "",
                      const context::ptr& defaults = NULL);
    virtual ~command_processor(void) {}

public:
    /* Accessor methods. */
    const std::vector<context::ptr>& output_contexts(void) const
        { return _output_contexts; }
    const std::vector<build_system::ptr>& vendored(void) const
        { return _vendored; }
    const bool& given_version_command(void) const
        { return _given_version_command; }
    const bool& given_help_command(void) const
        { return _given_help_command; }
    const std::string& srcpath(void) const
        { return _srcpath; }
    const std::string& base(void) const
        { return _base; }
    const context::ptr& root_context(void) const
        { return _root; }
    const std::vector<test_suite::ptr>& test_suites(void) const
        { return _test_suites; }

    const std::string& default_test_suite(void) const
        { return _default_test_suite; }
    const command::ptr& default_test_suite_cmd(void) const
        { return _default_test_suite_cmd; }

    /* The suite of the given name, or NULL when this project has
     * never declared one. */
    test_suite::ptr test_suite_named(const std::string& name) const;

    /* Hands back a subproject that a SUBPROJECTS command asked for,
     * or an empty string once there aren't any left.  The path is
     * relative to where pconfigure was run and ends with a '/'. */
    std::string take_pending_subproject(void);

    /* Hands back the suffix of a Configfile that a CONFIG command
     * asked for, or an empty string once there aren't any left. */
    std::string take_pending_config(void);

public:
    /* Processes a single command, performing the action that should
     * be associated with that command. */
    void process(const command::ptr& command);

private:
    /* The half of process() that does the work.  The split exists
     * because TESTSRC and HEADERSRC are each two commands wearing one
     * hat and go back through here twice, and anything process()
     * says about the line as it was written has to be said once. */
    void process_one(const command::ptr& command);

    /* Points {COMPILE,LINK}OPTS, COMPILER and LINKER at something,
     * which every command that opens a target has to do.  This is a
     * function rather than an assignment so that forgetting the other
     * half of it -- that whatever was stale isn't stale any more --
     * isn't something a command added later can do. */
    void set_opts_target(const opts_target::ptr& target);

    /* Says that a command landed on a target that something else had
     * already closed, if one did.  Called by the four commands that
     * go through _opts_target, which are the only ones that can. */
    void check_opts_target(const command::ptr& cmd);

    /* Clears the stack until it reaches one of the following types of
     * context, saving every popped context into _all_contexts.  "by"
     * is the command doing the clearing, which is only used to say
     * which line closed a target that something later still tried to
     * write to. */
    void clear_until(const std::vector<context_type>& types,
                     const command::ptr& by);

    /* Duplicates the TOS, but with a new context type and an
     * argument, and then pushes it onto the stack. */
    void dup_tos_and_push(const context_type& type,
                          const command::ptr& cmd);

    /* Reads the "#pconfigure" lines out of a test's source, and out
     * of everything that source includes, processing each of them as
     * though it had been written in the Configfile at the point the
     * source was named.
     *
     * That point is what makes this worth doing: the test is open, so
     * a line read here lands on the test that carried it rather than
     * on whatever else happened to be nearby.  A Configfile saying
     * the same thing has to say it somewhere both the test and the
     * reader can be got to from, which is somewhere else. */
    void process_directives(const std::string& path);

    /* The test that's open right now, or NULL when none is.  A
     * TESTSRC is a TESTS and then a SOURCES, so the line written
     * directly underneath one has that source sitting between it and
     * the test it plainly meant -- which is the way anybody who reads
     * the manual is going to write it. */
    context::ptr enclosing_test(void) const;
};

#endif
