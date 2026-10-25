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

#include <map>
#include <memory>
#include <stack>
#include <utility>
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

    /* Every vendored tree bound anywhere in this run, by the
     * directory it resolved to, along with the line that bound it.
     * This one map is shared by every project's command processor,
     * which is what lets a subproject's line find a tree its parent
     * already bound, and the other way round: "_vendored" above only
     * sees this project's own. */
    std::shared_ptr<std::map<std::string, command::ptr>> _vendored_in_run;

    /* The object that should be touched for CONFIGUREOPTS, which is
     * whichever build system or subproject was named most
     * recently. */
    build_system::ptr _configure_target;

    /* The sets this project's tests are divided into, in the order
     * they were declared -- which is the order their rules come out
     * in, so it has to be stable. */
    std::vector<test_suite::ptr> _test_suites;

    /* TRUE once an AUTORECONFIGURE asked for this project's
     * dependencies to be worked out by the build rather than here.
     * The command is kept alongside it because a complaint about what
     * the mode can't do has to point at the line that asked for it.
     *
     * A subproject inherits this from whoever pulled it in, because
     * it is a property of the build rather than of one Configfile:
     * the subproject's Makefile is included by the one make was run
     * on, so both halves are read by the same make.  A tree that says
     * it itself still wins.
     *
     * The inheritance is positional, since a subproject is read where
     * its line appears: one read above the line was read without
     * it. */
    bool _autoreconfigure;
    command::ptr _autoreconfigure_cmd;

    /* TRUE once a subproject has been handed out to be read, which is
     * what makes an AUTORECONFIGURE below that point too late to mean
     * what it says.  It is not a count and not a list: the question
     * is only whether anything was read under the old answer. */
    bool _read_a_subproject;

    /* Every pconfigure subproject read so far, with what it was
     * handed and which of its libraries still use that.  A PREFIX or
     * CROSS_COMPILE below a subproject is a mistake only when the
     * line would have reached something there had it been written
     * above it, and the something that matters is a library: that is
     * what a program here links, and what it then has to find at run
     * time.  So what is kept is a library from the subproject or from
     * anything under it whose prefix, and one whose toolchain, is
     * still the one the subproject was handed -- or NULL when none
     * is, because every library there was given its own, or because
     * there are no libraries at all. */
    struct read_subproject {
        std::string base;
        std::string prefix;
        context::ptr prefix_library;
        std::string cross_compile;
        context::ptr cross_compile_library;
    };
    std::vector<read_subproject> _read_subprojects;

    /* The vendored pconfigure source a BOOTSTRAP named, spelled the
     * way every other directory in a run is: ending with a '/', and
     * empty when nothing said.  The command is kept alongside it
     * because a complaint about the tree it points at has to point
     * at the line that named it. */
    std::string _bootstrap;
    command::ptr _bootstrap_cmd;

    /* The suite that "make check" runs, as a DEFAULT_TEST_SUITE named
     * it, or empty when nothing said and "make check" means every
     * test the project has.  The command is kept alongside it because
     * a complaint about the name has to point at the line. */
    std::string _default_test_suite;
    command::ptr _default_test_suite_cmd;

    /* TRUE once an ABRT_IS_FAIL asked for a test that calls abort()
     * to be scored as a FAIL instead of an EROR.  ptest's default --
     * an uncaught signal is an EROR, same as a missing binary or an
     * unreadable result -- is correct for the general case: a crash
     * can mean the harness never finished running the test at all.
     * It is also common for a test whose only failure mode is a
     * libc assert() to look exactly like that every single time it
     * fails, so this exists for the project that would rather see
     * those in NFAIL. */
    bool _abrt_is_fail;
    command::ptr _abrt_is_fail_cmd;

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

    /* The directory every SRCPATH so far adds up to, ending in a
     * '/', and the last line that moved it.  That isn't _srcpath: a
     * second SRCPATH is read relative to the first, so after "a" and
     * then "b" the sources are under "b/a" while _srcpath says "b". */
    std::string _srcpath_tree;
    command::ptr _srcpath_cmd;

    /* The subprojects that have been asked for but not read yet.
     * They're handed back one at a time rather than read here,
     * because reading a project is the job of whoever owns this.
     * Each one comes with the line that asked for it, so that a
     * complaint about the subproject that can only be made once the
     * whole run has been read still has a line to point at. */
    std::vector<std::pair<std::string, command::ptr>> _pending_subprojects;

    /* Every tree a SUBPROJECTS or a BOOTSTRAP named, kept after it
     * has been handed out to be read and kept alongside the line that
     * named it.  Whether "make distclean" would remove one of these
     * is a question about the whole run rather than about the line:
     * a LIBDIR further down this Configfile moves a directory the
     * recipe removes, and so does a target in a project read later,
     * so it gets asked once everything has been read and has to be
     * able to point back here when the answer is yes. */
    std::vector<std::pair<std::string, command::ptr>> _named_subprojects;

    /* Every file a SOURCES (or a TESTSRC or HEADERSRC, through theirs)
     * or a GENERATE's script reads out of the source directory, by
     * the path it is read at and alongside the line that named it.
     * Kept for the same question as the trees above, asked at the
     * same point for the same reason: whether "make distclean" would
     * remove the file depends on output directories a later line or
     * a later project can still move. */
    std::vector<std::pair<std::string, command::ptr>> _read_sources;

    /* The CONFIG commands whose Configfiles haven't been read yet,
     * which are handed back the same way and for the same reason.
     * The whole command is kept rather than just the name it gave,
     * because the name can turn out to be one with no file behind
     * it, and the line that wrote it is what that error points at. */
    std::vector<command::ptr> _pending_configs;
    /* CONFIG_DEPS names a path rather than a Configfile, so there is
     * nothing to read -- but it is resolved against the source path of
     * the project whose line it was, exactly as a CONFIG is, and that
     * is knowledge project::process_line has and this does not.  So it
     * queues here and is registered there, which is also what makes
     * the two commands agree about what a relative path means. */
    std::vector<std::string> _pending_config_deps;

public:
    /* Creates a new, mostly empty command processor (there is a
     * default context on the stack, for example) for the project
     * rooted at "base" -- which is either empty, for the project
     * being configured, or a path ending in '/' for a subproject.
     * A subproject is also handed the vendored trees the run has
     * bound so far, as whoever pulled it in has them (see
     * vendored_in_run()), so that it adds to the same list. */
    command_processor(const std::string& base = "",
                      const context::ptr& defaults = NULL,
                      const std::shared_ptr<std::map<std::string,
                                                     command::ptr>>&
                          vendored_in_run = NULL);
    virtual ~command_processor(void) {}

public:
    /* Accessor methods. */
    const std::vector<context::ptr>& output_contexts(void) const
        { return _output_contexts; }
    const std::vector<build_system::ptr>& vendored(void) const
        { return _vendored; }
    const std::shared_ptr<std::map<std::string, command::ptr>>&
    vendored_in_run(void) const
        { return _vendored_in_run; }
    const std::vector<std::pair<std::string, command::ptr>>&
    named_subprojects(void) const
        { return _named_subprojects; }
    const std::vector<std::pair<std::string, command::ptr>>&
    read_sources(void) const
        { return _read_sources; }
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
    /* How strict the context the next line lands in asked to be,
     * which is what a complaint about that line has to go by. */
    const strict& strictness(void) const
        { return _stack.top()->strictness; }
    const std::vector<test_suite::ptr>& test_suites(void) const
        { return _test_suites; }

    const bool& autoreconfigure(void) const
        { return _autoreconfigure; }
    const command::ptr& autoreconfigure_cmd(void) const
        { return _autoreconfigure_cmd; }

    const std::string& bootstrap(void) const
        { return _bootstrap; }
    const command::ptr& bootstrap_cmd(void) const
        { return _bootstrap_cmd; }

    const std::string& default_test_suite(void) const
        { return _default_test_suite; }
    const command::ptr& default_test_suite_cmd(void) const
        { return _default_test_suite_cmd; }

    const bool& abrt_is_fail(void) const
        { return _abrt_is_fail; }
    const command::ptr& abrt_is_fail_cmd(void) const
        { return _abrt_is_fail_cmd; }

    /* The suite of the given name, or NULL when this project has
     * never declared one. */
    test_suite::ptr test_suite_named(const std::string& name) const;

    /* Hands back a subproject that a SUBPROJECTS command asked for,
     * or an empty string once there aren't any left.  The path is
     * relative to where pconfigure was run and ends with a '/'.
     * "asked_by" is set to the SUBPROJECTS (or BOOTSTRAP) line that
     * named it. */
    std::string take_pending_subproject(command::ptr& asked_by);

    /* Says that the subproject at "base", one of those handed out
     * above, has been read all the way through.  It was handed
     * "prefix" and "cross_compile", and the two libraries are the
     * ones from it or from under it that still use each of those, or
     * NULL (see _read_subprojects). */
    void subproject_was_read(const std::string& base,
                             const std::string& prefix,
                             const context::ptr& prefix_library,
                             const std::string& cross_compile,
                             const context::ptr& cross_compile_library);

    /* Hands back a CONFIG command whose Configfile hasn't been read
     * yet, or NULL once there aren't any left.  Its data is the
     * suffix of the Configfile it asked for. */
    command::ptr take_pending_config(void);
    std::string take_pending_config_dep(void);

public:
    /* Processes a single command, performing the action that should
     * be associated with that command. */
    void process(const command::ptr& command);

    /* Refuses a SRCPATH that doesn't name a directory.  It's asked
     * once the lines that could have moved the source tree have been
     * read rather than at each one, because a second SRCPATH is read
     * relative to the first: the first alone can name a directory that
     * only exists under the second. */
    void check_srcpath(void) const;

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
     * reader can be got to from, which is somewhere else.
     *
     * "script" says the test is one pbashc is going to expand, and
     * so a file in which an "#if" is refused rather than read. */
    void process_directives(const std::string& path, bool script);

    /* The test that's open right now, or NULL when none is.  A
     * TESTSRC is a TESTS and then a SOURCES, so the line written
     * directly underneath one has that source sitting between it and
     * the test it plainly meant -- which is the way anybody who reads
     * the manual is going to write it. */
    context::ptr enclosing_test(void) const;
};

#endif
