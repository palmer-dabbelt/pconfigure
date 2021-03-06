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
#include "language_list.h++"
#include <sstream>

context::context(void)
    : type(context_type::DEFAULT),
      prefix("/usr/local"),
      gen_dir("obj/proc"),
      bin_dir("bin"),
      lib_dir("lib"),
      libexec_dir("libexec"),
      obj_dir("obj"),
      src_dir("src"),
      hdr_dir("include"),
      test_dir("test"),
      check_dir("check"),
      test_binary(""),
      src_path(""),
      compile_opts(),
      link_opts(),
      dep_libs(),
      cmd(NULL),
      verbose(false),
      debug(false),
      languages(std::make_shared<language_list>()),
      autodeps(true),
      phc("phc"),
      children()
{
}

context::context(const context_type& _type,
                 const std::string& _prefix,
                 const std::string& _gen_dir,
                 const std::string& _bin_dir,
                 const std::string& _lib_dir,
                 const std::string& _libexec_dir,
                 const std::string& _obj_dir,
                 const std::string& _src_dir,
                 const std::string& _hdr_dir,
                 const std::string& _test_dir,
                 const std::string& _check_dir,
                 const std::string& _test_binary,
                 const std::string& _src_path,
                 const std::vector<std::string>& _compile_opts,
                 const std::vector<std::string>& _link_opts,
                 const std::vector<std::string>& _dep_libs,
                 const command::ptr& _cmd,
                 bool _verbose,
                 bool _debug,
                 const language_list::ptr& _languages,
                 bool _autodeps,
                 const std::string& _phc,
                 const std::vector<ptr>& _children)
    : type(_type),
      prefix(_prefix),
      gen_dir(_gen_dir),
      bin_dir(_bin_dir),
      lib_dir(_lib_dir),
      libexec_dir(_libexec_dir),
      obj_dir(_obj_dir),
      src_dir(_src_dir),
      hdr_dir(_hdr_dir),
      test_dir(_test_dir),
      check_dir(_check_dir),
      test_binary(_test_binary),
      src_path(_src_path),
      compile_opts(_compile_opts),
      link_opts(_link_opts),
      dep_libs(_dep_libs),
      cmd(_cmd),
      verbose(_verbose),
      debug(_debug),
      languages(_languages),
      autodeps(_autodeps),
      phc(_phc),
      children(_children)
{
}

context::ptr context::dup(void) const
{
    return dup(this->type);
}

context::ptr context::dup(const context_type& type) const
{
    return dup(type, this->cmd, this->children);
}

context::ptr context::dup(const context_type& type,
                          const command::ptr& cmd,
                          const std::vector<ptr>& children)
                          const
{
    return std::make_shared<context>(type,
                                     this->prefix,
                                     this->gen_dir,
                                     this->bin_dir,
                                     this->lib_dir,
                                     this->libexec_dir,
                                     this->obj_dir,
                                     this->src_dir,
                                     this->hdr_dir,
                                     this->test_dir,
                                     this->check_dir,
                                     this->test_binary,
                                     this->src_path,
                                     this->compile_opts,
                                     this->link_opts,
                                     this->dep_libs,
                                     cmd,
                                     this->verbose,
                                     this->debug,
                                     this->languages->dup(),
                                     this->autodeps,
                                     this->phc,
                                     children);
}

bool context::check_type(const std::vector<context_type>& types)
{
    for (const auto& type: types)
        if (this->type == type)
            return true;

    return false;
}

std::string context::as_tree_string(const std::string prefix) const
{
    std::stringstream ss;

    ss << prefix
       << "[" << std::to_string(type) << "]" << " "
       << cmd->data()
       << "\n";

    for (const auto& child: children)
        ss << child->as_tree_string(prefix + "  ");

    return ss.str();
}

void context::add_compileopt(const std::string& data)
{
    compile_opts.push_back(data);
}

void context::add_linkopt(const std::string& data)
{
    link_opts.push_back(data);
}

std::string std::to_string(const context::ptr& ctx)
{
    return std::string("{")
        + "type: " + std::to_string(ctx->type)
        + " cmd: " + std::to_string(ctx->cmd->debug())
        + "}";
}
