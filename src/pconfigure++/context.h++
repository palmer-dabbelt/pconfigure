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

class language_list;

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

    /***************************************************************
     * Filled in after command_processor::process                  *
     ***************************************************************/

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

    /* The location at which the output from LIBRARY commands should
     * go. */
    std::string lib_dir;

    /* The location at which the output from LIBEXEC commands should
     * go. */
    std::string libexec_dir;

    /* The location at which the output of intermediate build steps
     * goes. */
    std::string obj_dir;

    /* The location at whith the input from SOURCE commands should be
     * loaded from. */
    std::string src_dir;

    /* The location at which HEADER commands are sourced from (unless they have
     * a SOURCES command). */
    std::string hdr_dir;

    /* The location at which TEST source file are stored. */
    std::string test_dir;

    /* The location at which "make check" targets are stored. */
    std::string check_dir;

    /* If a binary should be tested, then this is the full context that was
     * used to build it. */
    std::string test_binary;

    /* This is a bit odd: essentially all reads (except src_dir and test_dir,
     * which have been munged already) have to be prefixed with "src_path". */
    std::string src_path;

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

    /* This is TRUE when this target should be built in VERBOSE mode. */
    bool verbose;

    /* This is TRUE when this target should be built in DEBUG mode. */
    bool debug;

    /* The list of languages that are availiable to be used when trying to link
     * sub-objects and tests and such. */
    const std::shared_ptr<language_list> languages;

    /* Should automatic dependency resolution be enabled for this target?. */
    bool autodeps;

    /***************************************************************
     * Filled in after language::find_all_children                 *
     ***************************************************************/

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
            const std::string& lib_dir,
            const std::string& libexec_dir,
            const std::string& obj_dir,
            const std::string& src_dir,
            const std::string& hdr_dir,
            const std::string& test_dir,
            const std::string& check_dir,
            const std::string& test_binary,
            const std::string& src_path,
            const std::vector<std::string>& compile_opts,
            const std::vector<std::string>& link_opts,
            const std::vector<std::string>& dep_libs,
            const command::ptr& cmd,
            bool verbose,
            bool debug,
            const std::shared_ptr<language_list>& languages,
            bool autodeps,
            const std::vector<ptr>& children);

public:
    /* Duplicates the current context, potentially substituting in
     * some new values. */
    ptr dup(void) const;
    ptr dup(const context_type& type) const;
    ptr dup(const context_type& type,
            const command::ptr& cmd,
            const std::vector<ptr>& children)
            const;

    /* Duplicates this context, dropping the compile and link options. */
    ptr without_clopts(void) const
    {
        auto o = this->dup();
        o->compile_opts = std::vector<std::string>();
        o->link_opts = std::vector<std::string>();
        return o;
    }

    /* Checks to see if the context matches one of the given types,
     * returning TRUE if it matches, and FALSE if it doesn't. */
    bool check_type(const std::vector<context_type>& types);

    /* Converts this context to a string, dumping the whole tree of
     * children out with it. */
    std::string as_tree_string(const std::string prefix = "") const;

    /* Lists both the compile and link options, for languages that
     * don't discriminate -- the hope here is that compilers can
     * optimize when they're available for inlining... */
    std::vector<std::string> clopts(void) const
        {
            auto opt = std::vector<std::string>();
            opt.insert(opt.end(), compile_opts.begin(), compile_opts.end());
            opt.insert(opt.end(), link_opts.begin(), link_opts.end());
            return opt;
        }

    /* Virtual methods from opts_target. */
public:
    void add_compileopt(const std::string& data);
    void add_linkopt(const std::string& data);
    const std::vector<std::string>& list_compile_opts(void) const
        { return compile_opts; }
    const std::vector<std::string>& list_link_opts(void) const
        { return link_opts; }
};

namespace std {
    std::string to_string(const ::context::ptr& ctx);
}

#endif
