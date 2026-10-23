/*
 * Copyright (C) 2015-2016 Palmer Dabbelt
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

#include "bash.h++"
#include "../language_list.h++"
#include "../pick_language.h++"
#include "../string_utils.h++"
#include <pinclude.h++>
#include <assert.h>
#include <iostream>
#include <sstream>

language_bash* language_bash::clone(void) const
{
    return new language_bash(this->list_compile_opts(),
                             this->list_link_opts());
}

bool language_bash::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::LIBRARY:
    case context_type::GENERATE:
    case context_type::HEADER:
    case context_type::PHONY:
        return false;

    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
    return language::all_sources_match(ctx, {".bash"});
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

bool language_bash::targets_handle(const context::ptr& ctx)
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::LIBRARY:
    case context_type::GENERATE:
    case context_type::PHONY:
        return false;

    /* A SOURCE is never built on its own, but it is asked about: the
     * answer for one is the answer BASH's own can_process() gives,
     * which is yes. */
    case context_type::HEADER:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
        return true;
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

/* The paths in the recipes below are bare words, for the reason
 * written out over language_cxx::compile_source(): a name holding a
 * quote, a space or a shell metacharacter does not build anywhere in
 * pconfigure, quoting these recipes would not change that, and the
 * whole of it is on makefile::path_prefix and under "Odd Behavior" in
 * doc/pconfigure.tex. */
std::vector<makefile::target::ptr>
language_bash::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::LIBRARY:
    case context_type::SOURCE:
    case context_type::PHONY:
        std::cerr << "Unimplemented context type: "
                  << std::to_string(ctx->type)
                  << "\n";
        std::cerr << ctx->as_tree_string("  ");
        abort();
        break;

    case context_type::HEADER:
    case context_type::BINARY:
    {
        /* BASH-like languages are designed to be super simple: since
         * all they do is just link all the sources together at the
         * end, there's no need for any internal targets at all. */
        auto target = ctx->bin_dir + "/" + ctx->cmd->data();

        auto short_cmd = this->compiler_pretty() + "\t" + ctx->cmd->data();

        auto sources = std::vector<makefile::target::ptr>();
        auto deps = std::vector<makefile::target::ptr>();
        auto tests = std::vector<makefile::target::ptr>();
        for (const auto& child: ctx->children) {
            if (child->type == context_type::SOURCE) {
                auto path = child->src_dir + "/" + child->cmd->data();
                sources.push_back(std::make_shared<makefile::target>(path));
                if (ctx->autodeps == true)
                    deps = deps + dependencies(path, this->clopts(ctx));
            }

            /* A test is a child of the thing it tests, and the project
             * only ever hands a language its output contexts -- so the
             * tests of a BASH binary are reached from here or they are
             * not reached at all.  They were not, and a TESTSRC under a
             * BASH binary built nothing and said nothing about it.  The
             * language is picked per test, because the test of a BASH
             * binary needn't be written in BASH. */
            if (child->type == context_type::TEST) {
                auto l = pick_language(ctx->languages, child);
                auto filtered_child = [&]() -> context::ptr
                    {
                        if (l->name() == this->name())
                            return child;

                        return child->without_clopts();
                    }();
                tests = tests + l->targets(filtered_child);
            }
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        auto command = std::string();
        command += this->compiler_command(ctx)
                   + " -i "
                   + sources[0]->name()
                   + " -o "
                   + target;

        for (const auto& str: this->clopts(ctx))
            command += " " + str;

        auto bin_subdir = target.substr(0, target.find_last_of("/"));

        auto commands = std::vector<std::string>{
            "mkdir -p " + bin_subdir,
            command
        };

        auto filename = ctx->cmd->debug()->filename();
        auto lineno = ctx->cmd->debug()->line_number();
        auto comment = std::vector<std::string>{
            "language_bash::targets() BINARY",
            filename + ":" + std::to_string(lineno)
        };

        auto bin_target = std::make_shared<makefile::target>(target,
                                                             short_cmd,
                                                             sources + deps,
                                                             global_targets,
                                                             commands,
                                                             comment);

        /* Targets that are never installed (TESTEXECs) just get built in
         * place, there's no install rule to go along with them. */
        if (ctx->install == false)
            return std::vector<makefile::target::ptr>{bin_target} + tests;

        auto install_path = "$(DESTDIR)" + ctx->installed(target);

        /* Whatever "make install" writes is something "make uninstall"
         * has to know how to take back out, and the only way it knows
         * is a target putting itself on both.  This rule used to name
         * just the one, so a script -- and a header or a perl script,
         * which are installed by this same code -- went in under the
         * prefix and stayed there after everything compiled beside it
         * had been removed. */
        auto global_install_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
            makefile::global_targets::UNINSTALL,
        };

        /* Copied next to where it goes and then renamed over it, for
         * the reason languages/cxx.c++ gives at more length: a "cp"
         * writes through the file that's already there, so a program
         * something has open is a program that changes underneath it
         * -- and on macOS, one whose code signature the kernel has
         * already checked and remembered against that same file. */
        auto install_commands = std::vector<std::string>{
            "mkdir -p $(DESTDIR)" + ctx->installed(bin_subdir),
#if defined(__gnu_linux__)
            "cp --reflink=auto -f " + target + " $@.tmp",
#else
            "cp -f " + target + " $@.tmp",
#endif
            "mv -f $@.tmp $@"
        };

        auto install_target = std::make_shared<makefile::target>(install_path,
                                                                short_cmd,
                                                                std::vector<makefile::target::ptr>{bin_target},
                                                                global_install_targets,
                                                                install_commands,
                                                                comment);

        return std::vector<makefile::target::ptr>{bin_target, install_target}
               + tests;
    }

    case context_type::TEST:
    {
        auto child_ctx = ctx->dup(context_type::BINARY);
        child_ctx->bin_dir = ctx->obj_dir + "/" + ctx->unbased(ctx->check_dir);
        auto bin_name = ctx->test_binary;
        auto bin_targets = vector_util::map(targets(child_ctx),
                                            [](const makefile::target::ptr& t)
                                            {
                                                return t->without(makefile::global_targets::ALL);
                                            });
        bin_targets = std::vector<makefile::target::ptr>{bin_targets[0]};
        /* A test under a PHONY has nothing it's testing, so there's
         * no program to wait for and none to hand it.  Everywhere
         * else this is the thing the test exercises. */
        auto deps = bin_targets;
        if (bin_name.size() > 0)
            deps = std::vector<makefile::target::ptr>{
                       std::make_shared<makefile::target>(bin_name)
                   } + deps;

        auto target_name = ctx->check_target();
        auto short_cmd = "CHECK\t" + ctx->cmd->data();
        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::CHECK,
            makefile::global_targets::CLEAN
        };
        auto test_name = ctx->obj_dir + "/" + ctx->unbased(ctx->check_dir) + "/" + ctx->cmd->data();

        /* A test that needs something built before it runs says so
         * with a TESTDEPS, and all that has to happen is that make
         * builds it first.  Every one of them is something this
         * project builds, which is what keeps this Makefile usable
         * on its own. */
        for (const auto& dep: ctx->based_test_deps())
            deps.push_back(std::make_shared<makefile::target>(dep));

        /* A test that reads what another test left behind says so
         * with a DEPTESTS, and make ordering the two is the whole of
         * it: the tarball the first one leaves is a prerequisite, so
         * the second one waits for it and runs again whenever it is
         * rewritten.  Whether the first one passed is not make's
         * question -- a failed test is still a finished one, and it's
         * "make report" that has an opinion about the result. */
        for (const auto& dep: ctx->based_dep_tests())
            deps.push_back(std::make_shared<makefile::target>(dep));

        /* Where the project that owns this test is rooted -- whatever its
         * SRCPATH says, which is its own directory unless it said
         * otherwise.  make is what makes it absolute, because a test runs
         * wherever make was run and only make knows where that was.
         *
         * A test attached to a program can work this out from
         * $PTEST_BINARY.  One attached to a PHONY has no program to work
         * it out from, and this is what it anchors on instead of a
         * relative path with two answers.
         *
         * It is also the one word of this recipe that is not a path
         * pconfigure wrote itself: it is wherever somebody checked the
         * project out, which is not the project's choice, and a
         * "/home/me/my proj" pasted in as text reaches ptest as two
         * arguments, the second of which it has never heard of.  So it is
         * quoted, and make expanding the $(abspath) from inside the quotes
         * is exactly what's wanted, since make has no idea they are there.
         * What single quotes still can't carry is a checkout path with a
         * single quote in it, since make puts that in after the quoting
         * was decided.
         */
        auto srcdir = string_utils::quoted("$(abspath " + ctx->src_path + ".)");

        /* Scratch that does not get collected, named after the test and
         * sitting beside the test's own compiled self under $OBJDIR.
         *
         * Beside the test rather than in the check directory, which is
         * the obvious place and is wrong: "make report" walks a check
         * directory with find and reads every file it lands on as a
         * result tarball, so a disk image left in there is handed to tar
         * as though it were one test's verdict.  $OBJDIR is the other
         * directory a test already has to itself, it is on the same
         * volume as the tree -- which is what keeps a copy-on-write
         * clone of a fixture cheap -- and "make clean" already removes
         * it. */
        auto scratch_dir = test_name + ".scratch";

        /* The directory the result goes in is the one this target sits
         * in, which is the target's check directory only when the test
         * does.  A TESTSRC can name a file in a directory of its own --
         * "nested/deep.bash" -- and its tarball then lands in that
         * directory under the check directory; making only the check
         * directory left ptest writing to a path that wasn't there, so
         * the test never got a result at all.  The check directory itself
         * is still what --checkdir names, since that is where every test
         * of this target looks for the others' results. */
        auto commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            "+" + makefile::tool_command("ptest") + " --test " + test_name + " --out " + target_name
                + (bin_name.size() > 0 ? " --bin " + bin_name : "")
                + " --srcdir " + srcdir
                + " --checkdir " + ctx->check_dir
                + " --scratchdir " + scratch_dir
        };
        auto comment = std::vector<std::string>{
            "language_bash::targets() CHECK"
        };
        auto check_target = std::make_shared<makefile::target>(target_name,
                                                               short_cmd,
                                                               deps,
                                                               global_targets,
                                                               commands,
                                                               comment)
            ->with_clean_extra(scratch_dir);

        return bin_targets + std::vector<makefile::target::ptr>{check_target};
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}

/* Every argument of "flag" on a pbashc command line, in either of the
 * two spellings pbashc reads: stuck on, or the word after the flag
 * when it stands alone.
 *
 * This is pbashc's reading rather than a compiler's, which is why it
 * isn't cxx_include_dirs(): pbashc knows "-I" and nothing else, and a
 * "-isystem" that this counted as a directory would be one the script
 * was never searched in.
 *
 * A line of COMPILEOPTS is a piece of a command line rather than one
 * word of it -- "-I inc" and "-Wall -Iinc" are each one line -- and
 * the shell is what splits it before pbashc sees it, so it is split
 * the same way here first. */
static std::vector<std::string>
pbashc_flag_arguments(const std::vector<std::string>& opts,
                      const std::string& flag)
{
    auto words = std::vector<std::string>();
    for (const auto& opt: opts) {
        std::istringstream ss(opt);
        std::string word;
        while (ss >> word)
            words.push_back(word);
    }

    auto out = std::vector<std::string>();
    for (size_t i = 0; i < words.size(); ++i) {
        if (words[i].compare(0, flag.size(), flag) != 0)
            continue;

        if (words[i].size() > flag.size())
            out.push_back(words[i].substr(flag.size()));
        else if (i + 1 < words.size())
            out.push_back(words[++i]);
    }
    return out;
}

std::vector<makefile::target::ptr>
language_bash::dependencies(const std::string& path,
                            const std::vector<std::string>& opts) const
{
    /* pbashc is run with the target's options, and it searches the
     * "-I" directories for an "#include" and reads the "-D" names in
     * an "#ifdef".  The list of what a script reads has to be found
     * the same way, or a helper that only those options lead to is
     * pasted into the script and then left off its prerequisites, so
     * that editing it never rebuilds the script.
     *
     * pinclude wants the names that are defined, and "-DNAME=value"
     * defines NAME, which is how pbashc reads it too. */
    auto include_dirs = pbashc_flag_arguments(opts, "-I");
    auto defined = std::vector<std::string>();
    for (const auto& define: pbashc_flag_arguments(opts, "-D"))
        defined.push_back(define.substr(0, define.find('=')));

    std::vector<makefile::target::ptr> out;
    /* A shell script's # is a comment leader, so nothing but the bare
     * "#include" that pbashc expands may be read as a directive here. */
    pinclude::list(path,
                   include_dirs,
                   defined,
                   [&](std::string p) {
                       auto t = std::make_shared<makefile::target>(p);
                       out.push_back(t);
                       return 0;
                   }, true, true);
    return out;
}

static void install_bash(void) __attribute__((constructor));
void install_bash(void)
{
    language_list::global_add(
        std::make_shared<language_bash>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
