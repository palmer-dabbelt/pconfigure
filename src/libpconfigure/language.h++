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

#ifndef LANGUAGE_HXX
#define LANGUAGE_HXX

#include "context.h++"
#include "file_utils.h++"
#include "opts_target.h++"
#include "vector_util.h++"
#include <libmakefile/target.h++>
#include <memory>

/* Contains a single language.  Languages take contexts (which the
 * Configfile parser understands) and turn them into targets (which
 * the Makefile generator understands) in a way that's specific to
 * each source language. */
class language: public opts_target {
public:
    typedef std::shared_ptr<language> ptr;

private:
    /* These implement "opts_target" */
    std::vector<std::string> _compile_opts;
    std::vector<std::string> _link_opts;

    /* What a COMPILER or a LINKER written against this language said
     * to run, or empty when nobody said anything and whatever this
     * language does by default should happen. */
    std::string _compiler;
    std::string _linker;

public:
    language(const std::vector<std::string>& compile_opts,
             const std::vector<std::string>& link_opts);

    virtual ~language(void) {}

public:
    /* Accessor functions. */
    const std::vector<std::string>& compile_opts(void) const
        { return _compile_opts; }
    const std::vector<std::string>& link_opts(void) const
        { return _link_opts; }

public:
    /* Returns the name of this language, which is used as a unique
     * key when users refer to it from Configfiles. */
    virtual std::string name(void) const = 0;

    /* Returns a deep copy of this language, such that modifications
     * of the returned language will not effect this language.  Note
     * that this has to return a regular pointer (and not a
     * shared_ptr) because C++11 doesn't support covariant return
     * types. */
    virtual language* clone(void) const = 0;

    /* Every language writes its own clone(), and all any of them
     * copies is the options -- so anything added alongside them would
     * be quietly dropped by ten different functions.  Carrying it
     * across out here instead means a language that never heard of a
     * COMPILER still hands one down. */
    ptr dup(void) const
    {
        auto out = std::shared_ptr<language>(clone());
        out->_compiler = _compiler;
        out->_linker = _linker;
        return out;
    }

    /* What actually gets run to compile or link something.  Either
     * can be said at any scope, so the answer depends on what's being
     * built: what the target was told beats what the language was
     * told, which beats whatever the language does when nobody says
     * anything at all. */
    std::string compiler_command(const context::ptr& ctx) const
    {
        if (ctx->compiler.size() > 0)
            return ctx->compiler;
        if (_compiler.size() > 0)
            return _compiler;
        return default_compiler_command(ctx);
    }

    std::string linker_command(const context::ptr& ctx) const
    {
        if (ctx->linker.size() > 0)
            return ctx->linker;
        if (_linker.size() > 0)
            return _linker;
        return default_linker_command(ctx);
    }

    /* What this language runs when nobody has said otherwise.  These
     * take the context because a language that knows what a cross
     * toolchain would mean for it has to look at the CROSS_COMPILE
     * before it can name a program.  A language with nothing here is
     * one that never compiles (or never links), and being asked is a
     * bug rather than a default. */
    virtual std::string
    default_compiler_command(const context::ptr& ctx __attribute__((unused)))
    const
        { return ""; }

    virtual std::string
    default_linker_command(const context::ptr& ctx __attribute__((unused)))
    const
        { return ""; }

    /* Returns TRUE if this language can process the given context. */
    virtual bool can_process(const context::ptr& ctx) const = 0;

    /* Returns an arbitrary integer.  When multiple languages are
     * capable of processing a context then the one of largest
     * priority will be picked. */
    virtual int priority(void) const { return 0; }

    /* TRUE when an AUTODEPS decides what gets linked into a target as
     * well as when that target is rebuilt.
     *
     * That is the whole point of the command for a language that
     * compiles: turning it off keeps the sources behind a target's
     * headers out of it, which is a thing projects need and have no
     * other way to say.  A language that only ever concatenates its
     * sources has no such half, so AUTODEPS = false takes away the
     * rebuilding and gives nothing back, and whoever wrote it wanted
     * something else. */
    virtual bool autodeps_links(void) const { return true; }

    /* Returns the targets that this context needs in order to build,
     * as a flattened list. */
    virtual
    std::vector<makefile::target::ptr> targets(const context::ptr& ctx)
    const = 0;

    /* Lists both the compile and link options, for languages that
     * don't discriminate -- the hope here is that compilers can
     * optimize when they're available for inlining... */
    std::vector<std::string> clopts(void) const
        { return compile_opts() + link_opts(); }

    std::vector<std::string> clopts(const context::ptr& ctx) const
        { return compile_opts(ctx) + link_opts(ctx); }

    /* Combines {compile,link}-time options of this language with
     * those of a particular context. */
    std::vector<std::string> compile_opts(const context::ptr& ctx) const
        { return _compile_opts + ctx->compile_opts; }

    std::vector<std::string> link_opts(const context::ptr& ctx) const
        { return _link_opts + ctx->link_opts; }

    /* Says what a target this language produced can do for someone
     * else, and what it wants from someone else.  Matching one
     * against the other is how dependencies nobody wrote down get
     * found, including the ones that cross from one project into
     * another.
     *
     * Both sides of that are a language's job, because both mean
     * knowing the syntax of the tool being run: only the language
     * that wrote "-Llib -lfoo" onto a link line knows that it wants
     * whatever produces "lib/libfoo.so".  A language that can't read
     * its own command lines just wants nothing, and the dependencies
     * it needs have to be written down by hand.
     *
     * Every target offers itself by name, which is what lets a file
     * that's named outright on a command line be found. */
    virtual std::vector<std::string>
    provides(const makefile::target::ptr& target) const
        {
            return std::vector<std::string>{
                "file:" + file_utils::normalize_path(target->name())
            };
        }

    virtual std::vector<std::string>
    needs(const makefile::target::ptr& target __attribute__((unused))) const
        { return std::vector<std::string>(); }

    /* Virtual methods from opts_target. */
public:
    void add_compileopt(const std::string& data);
    void add_linkopt(const std::string& data);
    void set_compiler(const std::string& data) { _compiler = data; }
    void set_linker(const std::string& data) { _linker = data; }
    const std::vector<std::string>& list_compile_opts(void) const
        { return _compile_opts; }
    const std::vector<std::string>& list_link_opts(void) const
        { return _link_opts; }

protected:
    /* Returns TRUE if every source that's a direct child of the given
     * context is named with one of the given extensions.  A language
     * that can build a codebase is one that recognizes every file in
     * it, so a single name nobody claims is enough to say no. */
    static bool all_sources_match(const context::ptr& ctx,
                                  const std::vector<std::string>& extensions);
};

#endif
