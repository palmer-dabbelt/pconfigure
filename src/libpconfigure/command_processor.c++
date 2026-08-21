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
#include "commands.h++"
#include "languages/gen_proc.h++"
#include "languages/implicit_h.h++"
#include <iostream>

command_processor::command_processor(const std::string& base,
                                     const context::ptr& defaults)
    : _stack(),
      _opts_target(NULL),
      _given_version_command(false),
      _given_help_command(false),
      _srcpath(base.size() == 0 ? "." : base.substr(0, base.size() - 1)),
      _base(base),
      _root(std::make_shared<context>(base))
{
    /* A subproject is its own project, with its own languages and its
     * own directories, but it does get built and installed as part of
     * whoever pulled it in -- so it starts out installing to the same
     * place, and using the same tools.  Anything its own Configfile
     * says about either still wins. */
    if (defaults != NULL) {
        _root->prefix = defaults->prefix;
        _root->phc = defaults->phc;
        _root->verbose = defaults->verbose;
        _root->debug = defaults->debug;
    }

    _stack.push(_root);
    auto tos = _stack.top();
    tos->languages->add(std::make_shared<language_gen_proc>(
        std::vector<std::string>{},
        std::vector<std::string>{}
    ));
    tos->languages->add(std::make_shared<language_implicit_h>(
        std::vector<std::string>{},
        std::vector<std::string>{}
    ));
}

void command_processor::process(const command::ptr& cmd)
{
    auto tos = _stack.top();

    switch (cmd->type()) {
    case command_type::AUTODEPS:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        if (cmd->data() == "true") {
            tos->autodeps = true;
            return;
        }

        if (cmd->data() == "false") {
            tos->autodeps = false;
            return;
        }

        std::cerr << cmd->data() << " is not boolean\n";
        abort();
        return;
    }

    case command_type::BINARIES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::BINARY, cmd);

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        auto ctx = _stack.top();
        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

        return;
    }

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
        goto unimplemented;

    case command_type::CONFIG:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        /* Reading it is left to whoever owns this, so that the
         * lines inside it get run at the point they're processed
         * rather than all at once up front. */
        _pending_configs.push_back(cmd->data());

        return;
    }

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
        goto unimplemented;

    case command_type::HEADERS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::HEADER, cmd);

        _stack.top()->bin_dir = _stack.top()->hdr_dir;

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        return;
    }

    case command_type::LANGUAGES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        tos = _stack.top();

        if (tos->languages->search(cmd->data()) != NULL) {
            _opts_target = tos->languages->search(cmd->data());
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
        tos->languages->add(clone);
        _opts_target = clone;

        return;
    }

    case command_type::LIBDIR:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT});
        _stack.top()->lib_dir = _base + cmd->data();
        return;
    }

    case command_type::LIBEXECS:
    case command_type::TESTEXECS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::BINARY, cmd);

        auto ctx = _stack.top();
        if (cmd->type() == command_type::TESTEXECS) {
            /* TESTEXECs are just LIBEXECs that only the tests are
             * expected to run, so they're built but never installed. */
            ctx->bin_dir = ctx->testexec_dir;
            ctx->install = false;
        } else {
            ctx->bin_dir = ctx->libexec_dir;
        }

        _opts_target = ctx;
        _output_contexts.push_back(ctx);

        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

        return;
    }

    case command_type::LIBRARIES:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});
        dup_tos_and_push(context_type::LIBRARY, cmd);

        _opts_target = _stack.top();
        _output_contexts.push_back(_stack.top());

        auto ctx = _stack.top();
        ctx->test_binary = ctx->bin_dir + "/" + ctx->cmd->data();

        return;
    }

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
                    context_type::TEST,
                    context_type::HEADER,});
        dup_tos_and_push(context_type::SOURCE, cmd);

        _opts_target = _stack.top();

        return;

    case command_type::SRCDIR:
    {
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

        clear_until({context_type::DEFAULT});
        _stack.top()->src_dir = _base + cmd->data();
        return;
    }

    case command_type::SUBPROJECTS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT});

        /* Reading it is somebody else's job: this just says which one
         * was asked for, relative to where pconfigure is running
         * rather than to whoever asked. */
        _pending_subprojects.push_back(_base + cmd->data());

        return;
    }

    case command_type::TESTDEPS:
    case command_type::TESTDIR:
        goto unimplemented;

    case command_type::TESTS:
    {
        if (cmd->check_operation("+=") == false)
            goto bad_op_pluseq;

        clear_until({context_type::DEFAULT,
                    context_type::GENERATE,
                    context_type::LIBRARY,
                    context_type::BINARY,
                    context_type::HEADER,});
        auto parent = _stack.top();
        dup_tos_and_push(context_type::TEST, cmd);
        auto child = _stack.top();
        child->src_dir = parent->test_dir + "/" + parent->cmd->data();
        child->check_dir = parent->check_dir + "/" + parent->cmd->data();

        _opts_target = _stack.top();

        return;
    }

    case command_type::TESTSRC:
        process(cmd->with_type(command_type::TESTS));
        process(cmd->with_type(command_type::SOURCES));
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

    case command_type::VERSION:
        this->_given_version_command = true;
        return;

    case command_type::HELP:
        this->_given_help_command = true;
        return;

    case command_type::SRCPATH:
        if (cmd->check_operation("=") == false)
            goto bad_op_eq;

    {
        /* A SRCPATH is relative to the project it shows up in, which
         * is only the directory pconfigure was run from for the
         * top-level project. */
        auto path = _base + cmd->data();
        tos->src_dir = path + "/" + tos->src_dir.substr(_base.size());
        tos->test_dir = path + "/" + tos->test_dir.substr(_base.size());
        tos->src_path = path + "/";
        _srcpath = path;
        return;
    }

    case command_type::HEADERSRC:
        process(cmd->with_type(command_type::HEADERS));
        process(cmd->with_type(command_type::SOURCES));
        return;

    case command_type::DEBUG:
        _stack.top()->debug = true;
        return;

    case command_type::PHC:
        _stack.top()->phc = cmd->data();
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

std::string command_processor::take_pending_subproject(void)
{
    if (_pending_subprojects.size() == 0)
        return "";

    auto out = _pending_subprojects.front();
    _pending_subprojects.erase(_pending_subprojects.begin());
    return out;
}

std::string command_processor::take_pending_config(void)
{
    if (_pending_configs.size() == 0)
        return "";

    auto out = _pending_configs.front();
    _pending_configs.erase(_pending_configs.begin());
    return out;
}

void command_processor::clear_until(const std::vector<context_type>& types)
{
    while ((_stack.size() > 0) && (_stack.top()->check_type(types) == false)) {
        auto top = _stack.top();
        _stack.pop();
        _all_contexts.push_back(top);
    }

    if (_stack.size() == 0) {
        std::cerr << "Interal error: empty stack\n";
        abort();
    }
}

void command_processor::dup_tos_and_push(const context_type& type,
                                         const command::ptr& cmd)
{
    auto nctx = _stack.top()->dup(type, cmd, {});
    _stack.top()->children.push_back(nctx);
    _stack.push(nctx);
}
