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
#include "file_utils.h++"
#include "language_list.h++"
#include "vector_util.h++"
#include <libmakefile/self_path.h++>
#include <cstdlib>
#include <iostream>
#include <sstream>

context::context(const std::string& base)
    : type(context_type::DEFAULT),
      prefix("/usr/local"),
      gen_dir(base + "obj/proc"),
      bin_dir(base + "bin"),
      lib_dir(base + "lib"),
      libexec_dir(base + "libexec"),
      testexec_dir(base + "testexec"),
      obj_dir(base + "obj"),
      src_dir(base + "src"),
      hdr_dir(base + "include"),
      test_dir(base + "test"),
      check_dir(base + "check"),
      test_binary(""),
      src_path(base),
      compile_opts(),
      link_opts(),
      compiler(""),
      linker(""),
      cross_compile(""),
      strictness(),
      dep_libs(),
      test_deps(),
      dep_tests(),
      test_suite_name(""),
      cmd(NULL),
      verbose(false),
      debug(false),
      install(true),
      base(base),
      languages(std::make_shared<language_list>()),
      autodeps(true),
      autodeps_debug(NULL),
      phc(makefile::tool_command("phc")),
      entitlements(""),
      children()
{
}

context::context(const context_type& _type,
                 const std::string& _prefix,
                 const std::string& _gen_dir,
                 const std::string& _bin_dir,
                 const std::string& _lib_dir,
                 const std::string& _libexec_dir,
                 const std::string& _testexec_dir,
                 const std::string& _obj_dir,
                 const std::string& _src_dir,
                 const std::string& _hdr_dir,
                 const std::string& _test_dir,
                 const std::string& _check_dir,
                 const std::string& _test_binary,
                 const std::string& _src_path,
                 const std::vector<std::string>& _compile_opts,
                 const std::vector<std::string>& _link_opts,
                 const std::string& _compiler,
                 const std::string& _linker,
                 const std::string& _cross_compile,
                 const strict& _strictness,
                 const std::vector<std::string>& _dep_libs,
                 const std::vector<std::string>& _test_deps,
                 const std::vector<std::string>& _dep_tests,
                 const std::string& _test_suite_name,
                 const command::ptr& _cmd,
                 bool _verbose,
                 bool _debug,
                 bool _install,
                 const std::string& _base,
                 const language_list::ptr& _languages,
                 bool _autodeps,
                 const debug_info::ptr& _autodeps_debug,
                 const std::string& _phc,
                 const std::string& _entitlements,
                 const std::vector<ptr>& _children)
    : type(_type),
      prefix(_prefix),
      gen_dir(_gen_dir),
      bin_dir(_bin_dir),
      lib_dir(_lib_dir),
      libexec_dir(_libexec_dir),
      testexec_dir(_testexec_dir),
      obj_dir(_obj_dir),
      src_dir(_src_dir),
      hdr_dir(_hdr_dir),
      test_dir(_test_dir),
      check_dir(_check_dir),
      test_binary(_test_binary),
      src_path(_src_path),
      compile_opts(_compile_opts),
      link_opts(_link_opts),
      compiler(_compiler),
      linker(_linker),
      cross_compile(_cross_compile),
      strictness(_strictness),
      dep_libs(_dep_libs),
      test_deps(_test_deps),
      dep_tests(_dep_tests),
      test_suite_name(_test_suite_name),
      cmd(_cmd),
      verbose(_verbose),
      debug(_debug),
      install(_install),
      base(_base),
      languages(_languages),
      autodeps(_autodeps),
      autodeps_debug(_autodeps_debug),
      phc(_phc),
      entitlements(_entitlements),
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
                                     this->testexec_dir,
                                     this->obj_dir,
                                     this->src_dir,
                                     this->hdr_dir,
                                     this->test_dir,
                                     this->check_dir,
                                     this->test_binary,
                                     this->src_path,
                                     this->compile_opts,
                                     this->link_opts,
                                     this->compiler,
                                     this->linker,
                                     this->cross_compile,
                                     this->strictness,
                                     this->dep_libs,
                                     this->test_deps,
                                     this->dep_tests,
                                     this->test_suite_name,
                                     cmd,
                                     this->verbose,
                                     this->debug,
                                     this->install,
                                     this->base,
                                     this->languages->dup(),
                                     this->autodeps,
                                     this->autodeps_debug,
                                     this->phc,
                                     this->entitlements,
                                     children);
}

std::vector<std::string> context::based_test_deps(void) const
{
    /* A TESTDEPS is written relative to the project that named it,
     * the same way a SOURCES is, and normalizing is what turns the
     * "../" a sibling project has to be reached through into the one
     * spelling of that path everybody else in this Makefile uses. */
    return vector_util::map(test_deps,
                            [&](const std::string& dep)
                            {
                                return file_utils::normalize_path(base + dep);
                            });
}

std::string context::check_target(void) const
{
    if (type != context_type::TEST) {
        std::cerr << "Asked a " << std::to_string(type)
                  << " context what its check target is called, and only"
                  << " a TEST has one\n";
        abort();
    }

    return check_dir + "/" + cmd->data();
}

std::vector<std::string> context::based_dep_tests(void) const
{
    /* A DEPTESTS names a test of the same target, so what it names
     * lands in the same check directory this test's own result does
     * -- which is how the test being named wrote its own target
     * down, and so is the one spelling of that path the rest of the
     * Makefile uses.  A test that lives in a subdirectory of the test
     * directory keeps that subdirectory in both places, which is what
     * normalizing is here for. */
    return vector_util::map(dep_tests,
                            [&](const std::string& dep)
                            {
                                return file_utils::normalize_path(
                                    check_dir + "/" + dep);
                            });
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
