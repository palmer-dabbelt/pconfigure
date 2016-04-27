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

#include "language.h++"
#include <iostream>

language::language(const std::vector<std::string>& compile_opts,
                   const std::vector<std::string>& link_opts)
: _compile_opts(compile_opts),
  _link_opts(link_opts)
{
}

void language::add_compileopt(const std::string& data)
{
    _compile_opts.push_back(data);
}

void language::add_linkopt(const std::string& data)
{
    _link_opts.push_back(data);
}

bool language::all_sources_match(const context::ptr& ctx,
                                 const std::vector<std::regex>& rxs)
{
    for (const auto& child: ctx->children) {
        switch (child->type) {
        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::LIBRARY:
        case context_type::BINARY:
        case context_type::TEST:
            break;

        case context_type::SOURCE:
        {
            size_t matched = 0;
            for (const auto& rx: rxs) {
                if (std::regex_match(child->cmd->data(), rx))
                    matched++;
            }

            if (matched == 0)
                return false;

            break;
        }
        }
    }

    return true;
}
