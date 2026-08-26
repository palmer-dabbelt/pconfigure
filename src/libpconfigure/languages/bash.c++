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
#include <pinclude.h++>
#include <assert.h>
#include <iostream>

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
                    deps = deps + dependencies(path);
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

        auto install_path = "$(DESTDIR)/" + ctx->prefix + "/" + ctx->unbased(target);

        auto global_install_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
        };

        /* Copied next to where it goes and then renamed over it, for
         * the reason languages/cxx.c++ gives at more length: a "cp"
         * writes through the file that's already there, so a program
         * something has open is a program that changes underneath it
         * -- and on macOS, one whose code signature the kernel has
         * already checked and remembered against that same file. */
        auto install_commands = std::vector<std::string>{
            "mkdir -p $(DESTDIR)/" + ctx->prefix + "/" + ctx->unbased(bin_subdir),
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
         * relative path with two answers. */
        auto srcdir = "$(abspath " + ctx->src_path + ".)";

        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->check_dir,
            "+" + makefile::tool_command("ptest") + " --test " + test_name + " --out " + target_name
                + (bin_name.size() > 0 ? " --bin " + bin_name : "")
                + " --srcdir " + srcdir
                + " --checkdir " + ctx->check_dir
        };
        auto comment = std::vector<std::string>{
            "language_bash::targets() CHECK"
        };
        auto check_target = std::make_shared<makefile::target>(target_name,
                                                               short_cmd,
                                                               deps,
                                                               global_targets,
                                                               commands,
                                                               comment);

        return bin_targets + std::vector<makefile::target::ptr>{check_target};
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}

std::vector<makefile::target::ptr> language_bash::dependencies(const std::string& path) const
{
    std::vector<makefile::target::ptr> out;
    /* A shell script's # is a comment leader, so nothing but the bare
     * "#include" that pbashc expands may be read as a directive here. */
    pinclude::list(path,
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
