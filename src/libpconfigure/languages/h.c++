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
#include "../language_list.h++"
#include <assert.h>
#include <unistd.h>
#include <iostream>

language_h* language_h::clone(void) const
{
    return new language_h(this->list_compile_opts(),
                             this->list_link_opts());
}

bool language_h::can_process(const context::ptr& ctx) const
{
    if(language::all_sources_match(ctx,
                                   {std::regex(".*\\.h")})) {
        return true;
    }

    /* This works around a C++11 regex bug in GCC versions prior to
     * 4.9 -- specifically, I can't match the "c++" extension because
     * the old regex implementation doesn't appear to support escaping
     * the '+' character. */
    if (language::all_sources_match(ctx, {std::regex(".*\\.h..")})) {
        for (const auto& child: ctx->children) {
            switch (child->type) {
            case context_type::DEFAULT:
            case context_type::GENERATE:
            case context_type::LIBRARY:
            case context_type::BINARY:
            case context_type::TEST:
            case context_type::HEADER:
                break;

            case context_type::SOURCE:
            {
                auto file = child->cmd->data();
                if ((file.find(".h++", file.length() - 5) == std::string::npos)
                    && (file.find(".h", file.length() - 3) == std::string::npos)) {
                    return false;
                }
            }
            }
        }

        return true;
    }

    return false;
}

std::vector<makefile::target::ptr>
language_h::targets(const context::ptr& ctx) const
{
    auto bash_targets = language_bash::targets(ctx);

    for (const auto& t: bash_targets) {
        if (t->has_global_target(makefile::global_targets::INSTALL))
            continue;

        auto o = t->name();
        if (access(o.c_str(), R_OK) != 0) {
            for (const auto& cmd: t->cmds()) {
                if (system(cmd.c_str()) != 0) {
                    std::cerr << "system(\"" << cmd << "\") failed" << std::endl;
                    abort();
                }
            }
        }
    }

    return bash_targets;
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
