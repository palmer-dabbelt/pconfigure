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
    : _stack({std::make_shared<context>()})
{
}

void command_processor::process(const command::ptr& cmd)
{
    auto tos = _stack.top();

    switch (cmd->type()) {
    case command_type::AUTODEPS:
    case command_type::BINARIES:
    case command_type::COMPILEOPTS:
    case command_type::COMPILER:
    case command_type::CONFIG:
    case command_type::DEPLIBS:
    case command_type::GENERATE:
    case command_type::HDRDIR:
    case command_type::HEADERS:
    case command_type::LANGUAGES:
    case command_type::LIBDIR:
    case command_type::LIBEXECS:
    case command_type::LIBRARIES:
    case command_type::LINKER:
    case command_type::LINKOPTS:
        goto unimplemented;

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

    std::cerr << "Bad command index\n";
    abort();

bad_op_eq:
    std::cerr << "Command "
              << std::to_string(cmd->type())
              << " only supports '=', but given "
              << cmd->operation()
              << "\n";
    abort();
}
