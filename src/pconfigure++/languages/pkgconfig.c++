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

#include "pkgconfig.h++"
#include "../language_list.h++"
#include <assert.h>
#include <iostream>

language_pkgconfig* language_pkgconfig::clone(void) const
{
    return new language_pkgconfig();
}

bool language_pkgconfig::can_process(const context::ptr& ctx) const
{
    return language::all_sources_match(
        ctx,
        {
            std::regex(".*\\.pc"),
        }
        );
}

std::vector<makefile::target::ptr>
language_pkgconfig::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
        std::cerr << "Unimplemented context type: "
                  << std::to_string(ctx->type)
                  << "\n";
        std::cerr << ctx->as_tree_string("  ");
        abort();
        break;

    case context_type::LIBRARY:
    {
        /* BASH-like languages are designed to be super simple: since
         * all they do is just link all the sources together at the
         * end, there's no need for any internal targets at all. */
        auto target = ctx->bin_dir + "/" + ctx->cmd->data();

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
        command += "cat " + sources[0]->name();
        command += " | sed 's^@@pconfigure_prefix@@^" + ctx->prefix + "^g'";
#if 0
        /* FIXME: Add these in. */
        command += " | sed 's^@@pconfigure_libdir@@^" + ctx->lib_dir + "^g'";
        command += " | sed 's^@@pconfigure_hdrdir@@^" + ctx->hdr_dir + "^g'";
#endif
        for (const auto& str: this->clopts(ctx)) {
            if (strncmp(str.c_str(), "-S", 2) == 0)
                command += " | sed `cat " + str + "`";
            else
                command += " | sed '" + str + "'";
        }

        command += "> " + target;

        auto commands = std::vector<std::string>{command};

        auto bin_target = std::make_shared<makefile::target>(target,
                                                             sources,
                                                             global_targets,
                                                             commands);

        return {bin_target};
        break;
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}

static void install_pkgconfig(void) __attribute__((constructor));
void install_pkgconfig(void)
{
    language_list::global_add(std::make_shared<language_pkgconfig>());
}
