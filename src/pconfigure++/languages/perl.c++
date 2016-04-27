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

#include "perl.h++"
#include "../language_list.h++"
#include <assert.h>
#include <iostream>

bool language_perl::can_process(const context::ptr& ctx) const
{
    return language::all_sources_match(
        ctx,
        {
            std::regex(".*\\.pl"),
        }
        );
}

static void install_perl(void) __attribute__((constructor));
void install_perl(void)
{
    language_list::global_add(std::make_shared<language_perl>());
}
