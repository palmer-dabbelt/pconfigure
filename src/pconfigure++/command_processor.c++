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

#include "command_processor.h++"
#include <iostream>

command_processor::command_processor(void)
    : _stack({std::make_shared<context>()}),
      _languages(std::make_shared<language_list>()),
      _opts_target(NULL)
{
}

void command_processor::process(const command::ptr& cmd)
{
    auto tos = _stack.top();

    switch (cmd->type()) {
    case command_type::AUTODEPS:
    case command_type::BINARIES:
        goto unimplemented;

    case command_type::COMPILEOPTS:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        _opts_target->add_compileopt(cmd->data());

        return;

    case command_type::COMPILER:
    case command_type::CONFIG:
    case command_type::DEPLIBS:
    case command_type::GENERATE:
    case command_type::HDRDIR:
    case command_type::HEADERS:
        goto unimplemented;

    case command_type::LANGUAGES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        if (_languages->search(cmd->data()) != NULL) {
            _opts_target = _languages->search(cmd->data());
            return;
        }

        auto new_language = language_list::global_search(cmd->data());

        if (new_language == NULL) {
            std::cerr << "Unable to find language: '"
                      << cmd->data()
                      << "'\n";
            abort();
        }

        auto clone = language::ptr(new_language->clone());
        _languages->add(clone);
        _opts_target = clone;

        return;
    }

    case command_type::LIBDIR:
    case command_type::LIBEXECS:
    case command_type::LIBRARIES:
    case command_type::LINKER:
        goto unimplemented;

    case command_type::LINKOPTS:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        _opts_target->add_linkopt(cmd->data());

        return;

    case command_type::PREFIX:
        if (cmd->check_operation("=") != true)
            goto bad_op_eq;

        tos->prefix = cmd->data();

        return;

    case command_type::SOURCES:
    case command_type::SRCDIR:
    case command_type::TESTDEPS:
    case command_type::TESTDIR:
    case command_type::TESTS:
    case command_type::TESTSRC:
    case command_type::TGENERATE:
        unimplemented:
        std::cerr << "Command "
                  << std::to_string(cmd->type())
                  << " not implemented\n";
        abort();
        break;
    }

    std::cerr << "Bad command index on '"
              << std::to_string(cmd->debug())
              << "'\n";
    abort();

bad_op_eq:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " only supports '=', but given "
              << cmd->operation()
              << "\n";
    abort();

bad_op_pluseq:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " only supports '+=', but given "
              << cmd->operation()
              << "\n";
    abort();

no_opts_target:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " needs an *OPTS target, but none exists\n";
    abort();
}
