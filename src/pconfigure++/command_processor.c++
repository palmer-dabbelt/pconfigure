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
        goto unimplemented;

    case command_type::BINARIES:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::BINARY, cmd);

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        return;

    case command_type::COMPAT:
        /* FIXME: The only way I currently get here is through a
         * checked pconfigure command type, but I do eventually need
         * to do _something_ here... */
        return;

    case command_type::COMPILEOPTS:
        if (_opts_target == NULL)
            goto no_opts_target;

        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        _opts_target->add_compileopt(cmd->data());

        return;

    case command_type::COMPILER:
    case command_type::CONFIG:
        goto unimplemented;

    case command_type::DEPLIBS:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        if (_stack.top()->check_type({context_type::BINARY,
                                      context_type::LIBRARY,
                                      context_type::GENERATE,
                                      context_type::TEST,}) == false) {
            std::cerr << "Attempted to add DEPLIB to a "
                      << std::to_string(_stack.top()->type)
                      << " context, which isn't supported"
                      << "\n";
            abort();
        }

        _stack.top()->dep_libs.push_back(cmd->data());

        return;

    case command_type::GENERATE:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::GENERATE, cmd);

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        dup_tos_and_push(context_type::SOURCE,
                         std::make_shared<command>(
                             cmd->type(),
                             "+=",
                             cmd->data() + ".proc",
                             cmd->debug()
                             )
            );

        return;

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
        goto unimplemented;

    case command_type::LIBEXECS:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::BINARY, cmd);

        _stack.top()->bin_dir = _stack.top()->libexec_dir;

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        return;

    case command_type::LIBRARIES:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::LIBRARY, cmd);

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        return;

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
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT,
                    context_type::GENERATE,
                    context_type::LIBRARY,
                    context_type::BINARY,
                    context_type::TEST});
        dup_tos_and_push(context_type::SOURCE, cmd);

        _opts_target = _stack.top();

        return;

    case command_type::SRCDIR:
    case command_type::TESTDEPS:
    case command_type::TESTDIR:
        goto unimplemented;

    case command_type::TESTS:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT,
                    context_type::GENERATE,
                    context_type::LIBRARY,
                    context_type::BINARY,});
        dup_tos_and_push(context_type::TEST, cmd);

        _opts_target = _stack.top();

        return;

    case command_type::TESTSRC:
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT,
                    context_type::GENERATE,
                    context_type::LIBRARY,
                    context_type::BINARY,});
        dup_tos_and_push(context_type::TEST, cmd);
        dup_tos_and_push(context_type::SOURCE, cmd);
        _opts_target = _stack.top();

        return;

    case command_type::TGENERATE:
        unimplemented:
        std::cerr << "Command "
                  << std::to_string(cmd->type())
                  << " not implemented\n";
        abort();
        break;

    case command_type::VERBOSE:
        _stack.top()->verbose = true;
        return;
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

void command_processor::clear_until(const std::vector<context_type>& types)
{
    while ((_stack.size() > 0) && (_stack.top()->check_type(types) == false)) {
        auto top = _stack.top();
        _stack.pop();
        _all_contexts.push_back(top);
    }
}

void command_processor::dup_tos_and_push(const context_type& type,
                                         const command::ptr& cmd)
{
    auto nctx = _stack.top()->dup(type, cmd, {});
    _stack.top()->children.push_back(nctx);
    _stack.push(nctx);
}
