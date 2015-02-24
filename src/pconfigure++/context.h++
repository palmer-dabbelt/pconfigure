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

#ifndef CONTEXT_HXX
#define CONTEXT_HXX

#include <memory>
#include <string>
#include "context_type.h++"
#include "command.h++"
#include "opts_target.h++"

/* The super-entry for a context.  There will be one of these contexts
 * for everything the build system knows about.  This pretty much
 * duplicates the design of the original C code (and therefor the
 * Configfile language): the state of the system consists of a stack
 * of these contexts, most commands modify the state of that stack
 * (some effect global variables). */
class context: public opts_target {
public:
    typedef std::shared_ptr<context> ptr;

public:
    /* Yes, that's right -- there's public data here!  Essentially a
     * context is just a big structure where anything can change at
     * any time, so it kind of makes sense... */

    /* Identifies what sort of command generated this context. */
    const context_type type;

    /* The location into which the resulting files will be
     * installed. */
    std::string prefix;

    /* The location at which the output from GENERATE commands should
     * go. */
    std::string gen_dir;

    /* The location at which the output from BINARY commands should
     * go. */
    std::string bin_dir;

    /* The location at which the output from LIBEXEC commands should
     * go. */
    std::string libexec_dir;

    /* These implement "opts_target" */
    std::vector<std::string> compile_opts;
    std::vector<std::string> link_opts;

    /* The list of internal libraries that this target depends on.
     * These need to be both linked in at link-time, and trigger a
     * re-link if they've changed. */
    std::vector<std::string> dep_libs;

    /* The exact command issued, which allows all sorts of debugging
     * later. */
    const command::ptr cmd;

    /* The children of this context. */
    std::vector<ptr> children;

public:
    /* Creates a new context with everything filled in to the default
     * values.  Note that you probably don't want to use this unless
     * you're creating a new context stack, you really want to
     * clone a context and then modify it. */
    context(void);

    /* Allows every field inside a context to be set. */
    context(const context_type& type,
            const std::string& prefix,
            const std::string& gen_dir,
            const std::string& bin_dir,
            const std::string& libexec_dir,
            const command::ptr& cmd,
            const std::vector<ptr>& children);

public:
    /* Duplicates the current context, potentially substituting in
     * some new values. */
    ptr dup(void);
    ptr dup(const context_type& type,
            const command::ptr& cmd,
            const std::vector<ptr>& children);

    /* Checks to see if the context matches one of the given types,
     * returning TRUE if it matches, and FALSE if it doesn't. */
    bool check_type(const std::vector<context_type>& types);

    /* Converts this context to a string, dumping the whole tree of
     * children out with it. */
    std::string as_tree_string(const std::string prefix = "") const;

    /* Virtual methods from opts_target. */
    virtual void add_compileopt(const std::string& data);
    virtual void add_linkopt(const std::string& data);
};

#endif
