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

    /* The test suite this test was written into, as the name in the
     * brackets of its TESTS line spelled it, or empty for a test that
     * was written without one.
     *
     * Like the DEPTESTS above this belongs to a single test rather
     * than to a target: which tests of a target can be run on a given
     * machine is a question about the tests, and a target whose tests
     * are all in one suite is a target that says so once per test. */
    std::string test_suite_name;

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

    /* The AUTODEPS line that last set the above, or NULL when nothing
     * did and this is still the default.
     *
     * A warning about an AUTODEPS wants to point at the AUTODEPS, and
     * by the time anything is in a position to notice there is
     * something worth warning about, the line is a long way behind:
     * one line at the top of a target is read by every source and
     * every test underneath it.  Keeping it here is also what lets
     * fifty targets that inherited one line be complained about
     * once. */
    debug_info::ptr autodeps_debug;

    /* The path to the header compiler. */
    std::string phc;

    /* Where that path was given -- the PHC line or the "--phc" on the
     * command line -- or NULL when it's still the phc that came with
     * pconfigure.  A header copy that can't find its tool is a
     * mistake in that line rather than in the header, and this is
     * what lets the complaint point at it.  Not one of the
     * constructor's arguments, like build_made below: only the PHC
     * command sets it, and dup() carries it along. */
    debug_info::ptr phc_debug;

    /* The entitlements this target's code signature should carry,
     * named as a path to a plist relative to the project it belongs
     * to, or empty when it should carry none.  This only means
     * anything on macOS, where the signature is the only place the
     * kernel looks to find out what a binary is allowed to do. */
    std::string entitlements;

    /* The Apple frameworks this target should link against, named the
     * way "-framework" wants them (no path, no extension).  This only
     * means anything when the thing being linked is a Mach-O: like
     * entitlements, it's accepted on every platform so a Configfile
     * never has to ask which machine is reading it, and is silently
     * empty of effect anywhere else. */
    std::vector<std::string> frameworks;

    /***************************************************************
     * Filled in after language::find_all_children                 *
     ***************************************************************/

    /* The children of this context. */
    std::vector<ptr> children;

    /***************************************************************
     * Filled in after project::generate_targets                   *
     ***************************************************************/

    /* TRUE when something this project builds actually lands in
     * lib_dir.
     *
     * No context can work this out on its own: the one being linked
     * knows where a library would go, but not whether the project
     * ever asked for one, and that question isn't answered until the
     * last Configfile line has been read.  The project fills this in
     * for every context it knows about, and a link line reads it to
     * decide whether the directory is worth searching. */
    bool lib_dir_built;

    /* TRUE when this project's dependencies are worked out by the
     * build rather than by pconfigure, which an AUTORECONFIGURE asked
     * for.
     *
     * It is a property of the whole project, so it is stamped onto
     * every context after the Configfiles have been read rather than
     * set by the line that asked: a line at the bottom of a file has
     * to mean the same thing as the same line at the top. */
    bool autoreconfigure;

    /* The files this project's GENERATE and HEADERSRC lines make,
     * which a source can #include like any other header and which are
     * not on disk after a "make clean" or a deleted object directory.
     *
     * Only read under AUTORECONFIGURE, where it is handed to pdeps:
     * that is the one place the headers a source reads are worked out
     * while the build is happening, and so the one place a header the
     * build has not got round to making yet would otherwise go
     * unnoticed.  Stamped on by the project once every one of them is
     * known, like the two above, and not one of the constructor's
     * arguments because nothing but the project ever sets it. */
    std::vector<std::string> build_made;

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
            const std::string& test_suite_name,
            const command::ptr& cmd,
            bool verbose,
            bool debug,
            bool install,
            const std::string& base,
            const std::shared_ptr<language_list>& languages,
            bool autodeps,
            const debug_info::ptr& autodeps_debug,
            const std::string& phc,
            const std::string& entitlements,
            const std::vector<std::string>& frameworks,
            const std::vector<ptr>& children,
            bool lib_dir_built,
            bool autoreconfigure);

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

    /* Duplicates this context, dropping the compile and link options
     * it took from "above", the target it was opened under.
     *
     * Those were said to that target's language, and this context is
     * about to be built by a different one.  What was written under
     * this context itself is its own, though, and is kept: a TESTSRC
     * that says "COMPILEOPTS += -DTESTING" underneath it means it for
     * the test, in the test's language.
     *
     * The dropping goes all the way down rather than stopping here,
     * because the sources under this context were copied from it, and
     * so from "above", before anyone knew which language would build
     * them -- and a source is where a compile line reads its options
     * from.  Clearing them here alone left a C test of a C++ program
     * compiled with the program's flags, and a C++ test of a "-std=c99
     * -Werror" C program refused by its own compiler. */
    ptr without_clopts(const ptr& above) const
    {
        auto o = this->dup();
        o->drop_inherited_clopts(above->compile_opts, above->link_opts);

        /* Whatever was said about how to build this target was said
         * to a different language than the one that's about to build
         * it, and none of it can be expected to mean anything over
         * there -- which goes for the name of the compiler just as
         * much as for the options it was going to be handed. */
        o->drop_toolchain();
        return o;
    }

    /* Takes the leading options this context and everything under it
     * share with the ones given, which is how a context inherited
     * them: each is a copy of the one it was opened under, made with
     * that one's options as they stood, and anything written under
     * it since went on the end.  Comparing rather than counting means
     * an option that isn't actually shared is never taken.  Copies
     * are made on the way down, as drop_toolchain() does, so the
     * contexts this was copied from are left exactly as they were. */
    void drop_inherited_clopts(const std::vector<std::string>& compile,
                               const std::vector<std::string>& link)
    {
        compile_opts = without_prefix(compile_opts, compile);
        link_opts = without_prefix(link_opts, link);

        auto dropped = std::vector<ptr>();
        for (const auto& child: children) {
            auto copy = child->dup();
            copy->drop_inherited_clopts(compile, link);
            dropped.push_back(copy);
        }
        children = dropped;
    }

    static std::vector<std::string>
    without_prefix(const std::vector<std::string>& opts,
                   const std::vector<std::string>& prefix)
    {
        size_t shared = 0;
        while (shared < opts.size() && shared < prefix.size()
               && opts[shared] == prefix[shared])
            shared++;
        return std::vector<std::string>(opts.begin() + shared, opts.end());
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

    /* Strips whatever is between where pconfigure was run and the top
     * of the source tree off a directory, which is the base plus any
     * SRCPATH or "--srcpath": the directory as it sits in the source
     * tree, as opposed to how to get there from here.
     *
     * That's the spelling a source's object is named with under the
     * object directory.  unbased() leaves a srcpath on, and a srcpath
     * is a route to the checkout rather than a part of it: pasted
     * under "obj", the ".." in "../checkout" cancels the "obj" and the
     * objects land in "checkout/src" in the build directory, and a
     * second ".." takes them out of the build directory altogether --
     * which is the one place a separate build directory promises they
     * won't go.  Without a srcpath src_path is just the base, so this
     * is unbased() and object paths are what they always were.  A
     * directory that isn't under the source tree at all, which is
     * what a SRCDIR after a SRCPATH gives, falls back to unbased(). */
    std::string in_source_tree(const std::string& dir) const
    {
        if (src_path.size() > 0
            && dir.compare(0, src_path.size(), src_path) == 0)
            return dir.substr(src_path.size());
        return unbased(dir);
    }

    /* Where one of this project's directories ends up once installed:
     * the prefix with the directory, as unbased() spells it, hung off
     * the end.  This is the one place a directory gets joined onto the
     * prefix, so that every path built from it -- the install recipes,
     * the RUNPATH and __PCONFIGURE__LIBEXEC -- agrees on the spelling.
     * The prefix never ends in a '/' unless it is "/" itself, which is
     * why that one is special: pasting a '/' after it is how
     * "PREFIX = /" used to install into "//bin" and link "//lib" in as
     * the RUNPATH. */
    std::string installed(const std::string& dir) const
    {
        auto relative = unbased(dir);
        if (prefix.size() > 0 && prefix.back() == '/')
            return prefix + relative;
        return prefix + "/" + relative;
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

    /* Whether this is a LIBRARIES whose name asks for a static
     * archive -- "libfoo.a" -- rather than a shared library.  The
     * name is the only thing a Configfile has to say it with, and
     * both the language that builds the archive and the commands that
     * can't mean anything under one have to read it the same way. */
    bool is_static_archive(void) const;

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
    void add_framework(const std::string& data);
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
