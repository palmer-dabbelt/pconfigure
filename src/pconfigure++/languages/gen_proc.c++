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

#include "gen_proc.h++"
#include "../language_list.h++"
#include "../file_utils.h++"
#include <assert.h>
#include <iostream>

language_gen_proc* language_gen_proc::clone(void) const
{
    return new language_gen_proc();
}

bool language_gen_proc::can_process(const context::ptr& ctx) const
{
    return language::all_sources_match(
        ctx,
        {
            std::regex(".*\\.proc"),
        }
        );
}

std::vector<makefile::target::ptr>
language_gen_proc::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::BINARY:
    case context_type::LIBRARY:
    case context_type::SOURCE:
    case context_type::TEST:
        std::cerr << "Unimplemented context type: "
                  << std::to_string(ctx->type)
                  << "\n";
        std::cerr << ctx->as_tree_string("  ");
        abort();
        break;

    case context_type::GENERATE:
    {
        auto target = ctx->gen_dir + "/" + ctx->cmd->data();
        auto procfile = ctx->src_dir + "/" + ctx->cmd->data() + ".proc";

        auto sources = std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(procfile)
        };
        for (const auto& line: file_utils::execlines(procfile, {"--deps"})) {
            sources.push_back(std::make_shared<makefile::target>(line));
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        auto short_cmd = "GEN\t" + ctx->cmd->data();
        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->gen_dir,
            ctx->src_dir + "/" + ctx->cmd->data() + ".proc --generate > " + target
        };

        auto filename = ctx->cmd->debug()->filename();
        auto lineno = ctx->cmd->debug()->line_number();
        auto comment = std::vector<std::string>{
            "language_gen_proc::targets()",
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
