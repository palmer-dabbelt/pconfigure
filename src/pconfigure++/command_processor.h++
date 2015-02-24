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

#ifndef COMMAND_PROCESSOR_HXX
#define COMMAND_PROCESSOR_HXX

#include <memory>
#include <stack>
#include "command.h++"
#include "context.h++"
#include "language_list.h++"
#include "opts_target.h++"

/* Contains the entire state of the build system.  This processes a
 * list of commands and converts it into a graph of dependencies that
 * can then be fully flushed out in order to produce a proper list of
 * targets. */
class command_processor {
public:
    typedef std::shared_ptr<command_processor> ptr;

private:
    /* This is the stack that's visible to the user of pconfigure. */
    std::stack<context::ptr> _stack;

    /* The active language set. */
    language_list::ptr _languages;

    /* The object that should be touched for {COMPILE,LINK}OPTS. */
    opts_target::ptr _opts_target;

    /* A list of every target that's ever been part of the context
     * stack. */
    std::vector<context::ptr> _all_contexts;

public:
    /* Creates a new, mostly empty command processor (there is a
     * default context on the stack, for example). */
    command_processor(void);

public:
    /* Processes a single command, performing the action that should
     * be associated with that command. */
    void process(const command::ptr& command);

private:
    /* Clears the stack until it reaches one of the following types of
     * context, saving every popped context into _all_contexts. */
    void clear_until(const std::vector<context_type>& types);

    /* Duplicates the TOS, but with a new context type and an
     * argument, and then pushes it onto the stack. */
    void dup_tos_and_push(const context_type& type,
                          const command::ptr& cmd);
};

#endif
