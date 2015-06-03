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

#include "bash.h++"
#include "../language_list.h++"
#include <assert.h>
#include <iostream>

language_bash* language_bash::clone(void) const
{
    return new language_bash();
}

bool language_bash::can_process(const context::ptr& ctx) const
{
    return language::all_sources_match(
        ctx,
        {
            std::regex(".*\\.bash"),
        }
        );
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
    case context_type::TEST:
        std::cerr << "Unimplemented context type: "
                  << std::to_string(ctx->type)
                  << "\n";
        std::cerr << ctx->as_tree_string("  ");
        abort();
        break;

    case context_type::BINARY:
    {
        /* BASH-like languages are designed to be super simple: since
         * all they do is just link all the sources together at the
         * end, there's no need for any internal targets at all. */
        auto target = ctx->bin_dir + "/" + ctx->cmd->data();

        auto short_cmd = "BASHC\t" + ctx->cmd->data();

        auto sources = std::vector<makefile::target::ptr>();
        for (const auto& child: ctx->children) {
            if (child->type == context_type::SOURCE) {
                auto path = child->src_dir + "/" + child->cmd->data();
                sources.push_back(std::make_shared<makefile::target>(path));
            }
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        auto command = std::string();
        command += "pbashc -i " + sources[0]->name() + " -o " + target;

        for (const auto& str: this->clopts(ctx))
            command += " " + str;

        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->bin_dir,
            command
        };

        auto filename = ctx->cmd->debug()->filename();
        auto lineno = ctx->cmd->debug()->line_number();
        auto comment = std::vector<std::string>{
            "language_bash::targets()",
            filename + ":" + std::to_string(lineno)
        };

        auto bin_target = std::make_shared<makefile::target>(target,
                                                             short_cmd,
                                                             sources,
                                                             global_targets,
                                                             commands,
                                                             comment);

        return {bin_target};
        break;
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}

static void install_bash(void) __attribute__((constructor));
void install_bash(void)
{
    language_list::global_add(std::make_shared<language_bash>());
}
