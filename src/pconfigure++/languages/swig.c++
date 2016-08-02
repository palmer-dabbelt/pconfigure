/*
 * Copyright (C) 2015,2016 Palmer Dabbelt
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

#include "swig.h++"
#include "../language_list.h++"
#include <iostream>

language_swig* language_swig::clone(void) const
{
    return new language_swig(this->list_compile_opts(),
                             this->list_link_opts());
}

bool language_swig::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::HEADER:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
        return false;

    case context_type::LIBRARY:
        return language::all_sources_match(
            ctx,
            {
                std::regex(".*\\.i"),
            }
            );
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

static void install_swig(void) __attribute__((constructor));
void install_swig(void)
{
    language_list::global_add(
        std::make_shared<language_swig>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
