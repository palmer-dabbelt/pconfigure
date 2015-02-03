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

public:
    /* Creates a new, mostly empty command processor (there is a
     * default context on the stack, for example). */
    command_processor(void);

public:
    /* Processes a single command, performing the action that should
     * be associated with that command. */
    void process(const command::ptr& command);
};

#endif
