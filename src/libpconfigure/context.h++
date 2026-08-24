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
#include "strict.h++"
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

    /* The location at which the output from TESTEXEC commands should
     * go. */
    std::string testexec_dir;

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

    /* What to run to compile and link this target, or empty when
     * whatever language ends up building it should decide.  These sit
     * on the context rather than on the language because a project
     * that cross-compiles one binary and builds another for the
     * machine doing the building is still writing C in both. */
    std::string compiler;
    std::string linker;

    /* The name every tool in the toolchain that builds this target
     * starts with, or empty for the toolchain that builds things for
     * the machine running the build.  This is the spelling kbuild has
     * used for as long as anybody has been cross-compiling anything:
     * a prefix rather than a list of programs, because a toolchain is
     * a set of programs that were named together.
     *
     * It's kept apart from "compiler" on purpose.  Saying which
     * machine a target is for is a different statement than saying
     * what program to run, it's the one people actually want to make,
     * and a language that has no idea what a cross toolchain would
     * mean for it can ignore this and still be handed a COMPILER. */
    std::string cross_compile;

    /* How much of what pconfigure used to let a project get away with
     * it should still let this one get away with, which is what a
     * STRICT says.  This rides along on the context for the same
     * reason a CROSS_COMPILE does: a subproject inherits it from
     * whoever pulled it in, and a project that says nothing gets the
     * default. */
    strict strictness;

    /* The list of internal libraries that this target depends on.
     * These need to be both linked in at link-time, and trigger a
     * re-link if they've changed. */
    std::vector<std::string> dep_libs;

    /* The targets that have to exist before this context's tests are
     * run, named as whole paths rather than as library names.  A test
     * can want anything at all built first -- a tool that lives in a
     * sibling project, most of all -- and there's no short name that
     * covers all of that. */
    std::vector<std::string> test_deps;

    /* The tests that have to have run before this one does, named the
     * way their own TESTS line named them.  A test that reads what
     * another one left behind has to be told to wait for it, and the
     * Configfile that wrote both is the only thing that can say so.
     *
     * Unlike everything else here this belongs to a single test
     * rather than to a target: a target's copy would be read by every
     * test under it, including the one being waited for. */
    std::vector<std::string> dep_tests;

    /* The exact command issued, which allows all sorts of debugging
     * later. */
    const command::ptr cmd;

    /* This is TRUE when this target should be built in VERBOSE mode. */
    bool verbose;

    /* This is TRUE when this target should be built in DEBUG mode. */
    bool debug;

    /* This is FALSE when this target exists only as part of the build
     * (for example, a binary that only tests are expected to run), in
     * which case it's built by "make all" but never installed. */
    bool install;

    /* The directory this project is rooted at: either empty, or a
     * path that ends with a '/'. */
    std::string base;

    /* The list of languages that are availiable to be used when trying to link
     * sub-objects and tests and such. */
    const std::shared_ptr<language_list> languages;

    /* Should automatic dependency resolution be enabled for this target?. */
    bool autodeps;

    /* The path to the header compiler. */
    std::string phc;

    /* The entitlements this target's code signature should carry,
     * named as a path to a plist relative to the project it belongs
     * to, or empty when it should carry none.  This only means
     * anything on macOS, where the signature is the only place the
     * kernel looks to find out what a binary is allowed to do. */
    std::string entitlements;

    /***************************************************************
     * Filled in after language::find_all_children                 *
     ***************************************************************/

    /* The children of this context. */
    std::vector<ptr> children;

public:
    /* Creates a new context with everything filled in to the default
     * values.  Note that you probably don't want to use this unless
     * you're creating a new context stack, you really want to
     * clone a context and then modify it.
     *
     * "base" is the directory this project is rooted at, relative to
     * the directory pconfigure is running in.  It's either empty (for
     * the project being configured) or ends with a '/' (for a
     * subproject).  Every directory this context knows about is
     * rooted there, which is what allows a single pconfigure run to
     * configure more than one project. */
    context(const std::string& base = "");

    /* Allows every field inside a context to be set. */
    context(const context_type& type,
            const std::string& prefix,
            const std::string& gen_dir,
            const std::string& bin_dir,
            const std::string& lib_dir,
            const std::string& libexec_dir,
            const std::string& testexec_dir,
            const std::string& obj_dir,
            const std::string& src_dir,
            const std::string& hdr_dir,
            const std::string& test_dir,
            const std::string& check_dir,
            const std::string& test_binary,
            const std::string& src_path,
            const std::vector<std::string>& compile_opts,
            const std::vector<std::string>& link_opts,
            const std::string& compiler,
            const std::string& linker,
            const std::string& cross_compile,
            const strict& strictness,
            const std::vector<std::string>& dep_libs,
            const std::vector<std::string>& test_deps,
            const std::vector<std::string>& dep_tests,
            const command::ptr& cmd,
            bool verbose,
            bool debug,
            bool install,
            const std::string& base,
            const std::shared_ptr<language_list>& languages,
            bool autodeps,
            const std::string& phc,
            const std::string& entitlements,
            const std::vector<ptr>& children);

    virtual ~context(void) {}

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

        /* Whatever was said about how to build this target was said
         * to a different language than the one that's about to build
         * it, and none of it can be expected to mean anything over
         * there -- which goes for the name of the compiler just as
         * much as for the options it was going to be handed. */
        o->drop_toolchain();
        return o;
    }

    /* Forgets which toolchain builds this context, and everything
     * under it.
     *
     * The sources of a target were copied from the target before any
     * of this came up, so each of them is carrying its own copy of
     * the answer and has to be asked again -- otherwise the objects
     * come out built by one toolchain and the link that gathers them
     * up is run by another, which fails late and reads like a
     * corrupted object file rather than like a mistake in a
     * Configfile.  Copies are made on the way down so that the
     * context this was called on is left exactly as it was. */
    void drop_toolchain(void)
    {
        compiler = "";
        linker = "";
        cross_compile = "";

        auto dropped = std::vector<ptr>();
        for (const auto& child: children) {
            auto copy = child->dup();
            copy->drop_toolchain();
            dropped.push_back(copy);
        }
        children = dropped;
    }

    /* Strips this project's base off a directory, giving the path as
     * it looks from inside the project rather than from where
     * pconfigure was run.
     *
     * That's the spelling wanted whenever a path isn't naming a file
     * to build: where a file gets installed to, how far "bin" is from
     * "lib" for an rpath, and what to stick on the end of another
     * directory that's already based.  Prepending the base twice is
     * the easiest mistake to make here, and it produces paths that
     * look plausible and don't exist. */
    std::string unbased(const std::string& dir) const
    {
        if (base.size() > 0 && dir.compare(0, base.size(), base) == 0)
            return dir.substr(base.size());
        return dir;
    }

    /* The paths a TESTDEPS named, spelled the way the Makefile spells
     * them: relative to where pconfigure ran, with the project this
     * context belongs to already on the front.  Every one of them
     * names something inside that project, since a TESTDEPS that
     * reached outside was refused when it was read. */
    std::vector<std::string> based_test_deps(void) const;

    /* What this test's check target is called, which is both the rule
     * that runs the test and the tarball of whatever it left behind.
     * Only a TEST context has one. */
    std::string check_target(void) const;

    /* The check targets a DEPTESTS named, which is that same question
     * asked of another test of the same target.  A DEPTESTS is a bare
     * test name rather than a path because the only test it is
     * allowed to name is one that shares this check directory, so
     * that directory is the whole of what has to go on the front. */
    std::vector<std::string> based_dep_tests(void) const;

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
    void set_compiler(const std::string& data) { compiler = data; }
    void set_linker(const std::string& data) { linker = data; }
    const std::vector<std::string>& list_compile_opts(void) const
        { return compile_opts; }
    const std::vector<std::string>& list_link_opts(void) const
        { return link_opts; }
};

namespace std {
    std::string to_string(const ::context::ptr& ctx);
}

#endif
