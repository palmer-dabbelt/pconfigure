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
#include <assert.h>
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
