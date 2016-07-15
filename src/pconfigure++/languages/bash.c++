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
        return false;

    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
    return language::all_sources_match(
        ctx,
        {
            std::regex(".*\\.bash"),
        }
        );
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
        for (const auto& child: ctx->children) {
            if (child->type == context_type::SOURCE) {
                auto path = child->src_dir + "/" + child->cmd->data();
                sources.push_back(std::make_shared<makefile::target>(path));
                if (ctx->autodeps == true)
                    deps = deps + dependencies(path);
            }
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        auto command = std::string();
        command += this->compiler_command()
                   + " -i "
                   + sources[0]->name()
                   + " -o "
                   + target;

        for (const auto& str: this->clopts(ctx))
            command += " " + str;

        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->bin_dir,
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

        auto install_path = "$(DESTDIR)/" + ctx->prefix + "/" + target;

        auto global_install_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
        };

        auto install_commands = std::vector<std::string>{
            "mkdir -p $(DESTDIR)/" + ctx->prefix + "/" + ctx->bin_dir,
            "cp --reflink=auto -f " + target + " " + install_path
        };

        auto install_target = std::make_shared<makefile::target>(install_path,
                                                                short_cmd,
                                                                std::vector<makefile::target::ptr>{bin_target},
                                                                global_install_targets,
                                                                install_commands,
                                                                comment);

        return {bin_target, install_target};
    }

    case context_type::TEST:
    {
        auto child_ctx = ctx->dup(context_type::BINARY);
        child_ctx->bin_dir = ctx->obj_dir + "/" + ctx->check_dir;
        auto bin_name = ctx->test_binary;
        auto bin_targets = vector_util::map(targets(child_ctx),
                                            [](const makefile::target::ptr& t)
                                            {
                                                return t->without(makefile::global_targets::ALL);
                                            });
        bin_targets = std::vector<makefile::target::ptr>{bin_targets[0]};
        auto deps = std::vector<makefile::target::ptr>{
                        std::make_shared<makefile::target>(bin_name)
                    } + bin_targets;

        auto target_name = ctx->check_dir + "/" + ctx->cmd->data();
        auto short_cmd = "CHECK\t" + ctx->cmd->data();
        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::CHECK,
            makefile::global_targets::CLEAN
        };
        auto test_name = ctx->obj_dir + "/" + ctx->check_dir + "/" + ctx->cmd->data();
        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->check_dir,
            "+ptest --test " + test_name + " --out " + target_name + " --bin " + bin_name
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
    pinclude::list(path, {}, {},
                   [&](std::string p) {
                       auto t = std::make_shared<makefile::target>(p);
                       out.push_back(t);
                       return 0;
                   }, false);
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
