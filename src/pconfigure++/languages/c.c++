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

#include "c.h++"
#include "../language_list.h++"
#include <iostream>

language_c* language_c::clone(void) const
{
    return new language_c(this->list_compile_opts(),
                          this->list_link_opts());
}

bool language_c::can_process(const context::ptr& ctx) const
{
    return language::all_sources_match(
        ctx,
        {
            std::regex(".*\\.c"),
        }
        );
}

static void install_c(void) __attribute__((constructor));
void install_c(void)
{
    language_list::global_add(
        std::make_shared<language_c>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
