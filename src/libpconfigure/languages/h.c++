/*
 * Copyright (C) 2016 Palmer Dabbelt
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

#include "h.h++"
#include "cxx.h++"
#include "../language_list.h++"
#include "../file_utils.h++"
#include <assert.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <iostream>

language_h* language_h::clone(void) const
{
    return new language_h(this->list_compile_opts(),
                             this->list_link_opts());
}

/* TRUE when a path's last component has no extension on it at all. */
static bool extensionless(const std::string& path)
{
    auto slash = path.find_last_of('/');
    auto base = (slash == std::string::npos) ? path : path.substr(slash + 1);

    return base.empty() == false && base.find('.') == std::string::npos;
}

bool language_h::can_process(const context::ptr& ctx) const
{
    /* What this writes is BASH's targets() run on the headers, so a
     * LIBRARIES built out of nothing but headers is no more something
     * it can make than it is something BASH can: claiming it gets as
     * far as targets() and aborts there, without naming the line. */
    if (language_bash::targets_handle(ctx) == false)
        return false;

    /* The headers phc knows what to do with are C and C++ headers, so
     * which names those go by is the C++ language's to say. */
    if (language::all_sources_match(ctx, cxx_header_extensions()))
        return true;

    /* Except for the ones with no extension at all, which is how the C++
     * standard library spells every header it has: <queue>, <vector>,
     * <cstdint>.  A project shipping a header of its own that stands in for
     * one of those has to install it under exactly the name the #include
     * uses, so there is nowhere for an extension to go -- and without this
     * the only spelling left is a HEADERS with no SOURCES under it, which is
     * a different thing that reads the file out of the include directory and
     * cleans it up again afterwards.
     *
     * Only under a HEADERS, and only for a target that says what it is built
     * out of.  A name with no extension is not otherwise evidence of
     * anything, and a language that claimed one on that basis would be
     * claiming every file nobody else wanted. */
    if (ctx->type != context_type::HEADER)
        return false;

    if (ctx->children.size() == 0)
        return false;

    for (const auto& child: ctx->children) {
        switch (child->type) {
        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::LIBRARY:
        case context_type::BINARY:
        case context_type::TEST:
        case context_type::PHONY:
            break;

        case context_type::HEADER:
        case context_type::SOURCE:
            if (extensionless(child->cmd->data()) == false)
                return false;
            break;
        }
    }

    return true;
}

/* Whether make would call "target" out of date because of "dep": the
 * dependency is there and was written after the target was.  Down to
 * the nanosecond where the system says, since that is how make
 * compares them, and a reconfigure run in the same second as the copy
 * it is judging is exactly what an AUTORECONFIGURE build does.  A
 * dependency that isn't there is no reason here: whether it can be
 * made is make's question, and the copy below would only fail. */
static bool newer_than(const std::string& dep, const std::string& target)
{
    struct stat d, t;
    if (stat(dep.c_str(), &d) != 0 || stat(target.c_str(), &t) != 0)
        return false;

#if defined(__APPLE__)
    auto dm = d.st_mtimespec;
    auto tm = t.st_mtimespec;
#else
    auto dm = d.st_mtim;
    auto tm = t.st_mtim;
#endif

    if (dm.tv_sec != tm.tv_sec)
        return dm.tv_sec > tm.tv_sec;
    return dm.tv_nsec > tm.tv_nsec;
}

std::vector<makefile::target::ptr>
language_h::targets(const context::ptr& ctx) const
{
    auto bash_targets = language_bash::targets(ctx);

    /* The header is copied into place now, as well as by make, so that
     * whatever includes it can be scanned for its dependencies while
     * pconfigure is still running -- a header that isn't in the include
     * directory yet is one that scan can't follow.
     *
     * Only the copy itself is run.  What BASH hands back holds the
     * install rule and, for every TESTSRC under the HEADERS, that
     * test's check target too, and those are make recipes: "$(dir $@)"
     * means something to make and is a command substitution to a
     * shell.  Running them all used to make a mkdir of whatever "dir"
     * listed, and abort.  The copy is picked out by name rather than by
     * where it sits in the list, so that a change to the order BASH
     * returns things in can't quietly turn this back into running a
     * test. */
    auto header = ctx->bin_dir + "/" + ctx->cmd->data();
    for (const auto& t: bash_targets) {
        if (t->name() != header)
            continue;

        /* It used to be copied only when there was no copy, which left
         * a copy of a SOURCES the Configfile had since been pointed
         * away from sitting in the include directory until make got
         * around to it.  The rule names the recipe as a prerequisite,
         * and BASH's targets() has just rewritten that if the source or
         * the options moved, so asking the rule's own question -- is
         * anything it names newer than the copy -- is what catches
         * that, and what leaves a copy that is up to date alone. */
        auto stale = access(header.c_str(), R_OK) != 0;
        for (const auto& dep: t->deps())
            stale = stale || newer_than(dep->name(), header);
        if (stale == false)
            continue;

        /* A header whose input isn't there yet has nothing to copy
         * early, and that is not configure's to refuse: the input may
         * be on its way, and a missing SOURCES under a BINARY is left
         * for make to report in the same way.  make has the input as a
         * prerequisite of this same copy, so it says which file it
         * couldn't find, and builds the header once that file turns
         * up, without a reconfigure.  This used to run the copy anyway,
         * so "cp" said "cannot stat" and pconfigure aborted on a
         * system() it named without naming the line. */
        auto ready = true;
        for (const auto& dep: t->deps())
            if (access(dep->name().c_str(), R_OK) != 0)
                ready = false;
        if (ready == false)
            continue;

        for (const auto& cmd: t->cmds()) {
            auto status = system(cmd.c_str());

            /* The shell exits 127 when it found nothing to run and 126
             * when what it found couldn't be executed.  Said about the
             * command that runs the PHC, that is the tool itself
             * missing: the include directory is fine, and advice about
             * it sends the reader to the one thing that isn't the
             * problem.  So this names the tool instead, and where it
             * was chosen -- the PHC line, the "--phc" on the command
             * line, or nowhere, when it is the phc this pconfigure was
             * built with. */
            auto code = WIFEXITED(status) ? WEXITSTATUS(status) : 0;
            auto runs_phc = cmd.compare(0, ctx->phc.size(), ctx->phc) == 0;
            if (runs_phc && (code == 127 || code == 126)) {
                std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                          << "  error: '" << cmd << "' "
                          << file_utils::describe_wait_status(status)
                          << "\n";
                if (ctx->phc_debug != NULL) {
                    auto spelling = ctx->phc_debug->from_command_line()
                        ? std::string("'--phc'")
                        : std::string("that PHC");
                    std::cerr << "  the header compiler '" << ctx->phc
                              << "' was set by PHC at "
                              << std::to_string(ctx->phc_debug) << "\n"
                              << "  make " << spelling << " name a program"
                              << " that can be run, or leave it out to use"
                              << " the phc that came with pconfigure\n";
                } else
                    std::cerr << "  the header compiler '" << ctx->phc
                              << "' is the phc that came with pconfigure,"
                              << " and it couldn't be run\n"
                              << "  install pconfigure's phc there, or"
                              << " write 'PHC = <path>' (or give"
                              << " '--phc <path>') to use another\n";
                abort();
            }

            if (status != 0) {
                std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                          << "  error: '" << cmd << "' "
                          << file_utils::describe_wait_status(status)
                          << "\n"
                          << "  pconfigure copies " << ctx->cmd->data()
                          << " to " << header << " while it configures,"
                          << " so that what includes it can be scanned,"
                          << " and that copy has to succeed: check that "
                          << ctx->bin_dir << " is a directory pconfigure"
                          << " can write\n";
                abort();
            }
        }
    }

    return bash_targets;
}

/* phc is a "cp": the header that's installed is the one file, byte for
 * byte, with its "#include"s left for whoever reads it to resolve.  So
 * the advice BASH gives -- include the second from the first -- would
 * install a header pointing at one that was never installed beside it.
 * The second needs to be installed itself, which is a target of its
 * own. */
std::string
language_h::second_source_advice(const context::ptr& first,
                                 const context::ptr& second,
                                 const std::string& spelling
                                     __attribute__((unused))) const
{
    return "  give " + second->cmd->data()
         + " a HEADERS of its own instead: phc installs "
         + first->cmd->data()
         + " exactly as it is, and " + second->cmd->data()
         + " would never be installed at all\n";
}

static void install_h(void) __attribute__((constructor));
void install_h(void)
{
    language_list::global_add(
        std::make_shared<language_h>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
