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

#include "context.h++"

context::context(void)
    : type(context_type::DEFAULT),
      prefix("/usr/local"),
      gen_dir("obj/proc"),
      cmd(NULL)
{
}

context::context(const context_type& _type,
                 const std::string& _prefix,
                 const std::string& _gen_dir,
                 const command::ptr& _cmd)
    : type(_type),
      prefix(_prefix),
      gen_dir(_gen_dir),
      cmd(_cmd)
{
}

context::ptr context::dup(const context_type& type,
                          const command::ptr& cmd)
{
    return std::make_shared<context>(type,
                                     this->prefix,
                                     this->gen_dir,
                                     cmd);
}

bool context::check_type(const std::vector<context_type>& types)
{
    for (const auto& type: types)
        if (this->type == type)
            return true;

    return false;
}

void context::add_compileopt(const std::string& data)
{
    compile_opts.push_back(data);
}

void context::add_linkopt(const std::string& data)
{
    link_opts.push_back(data);
}
