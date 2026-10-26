/*
 * Copyright (C) 2015,2016 Palmer Dabbelt
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

#ifndef LANGUAGES__BASH_CXX
#define LANGUAGES__BASH_CXX

#include "../language.h++"
#include <libmakefile/self_path.h++>
#include <pinclude.h++>
#include <memory>

/* The files a script reads when pbashc or pperlc is run on it with
 * the given options, read the way that compiler reads them: only the
 * bare "#include" is a directive, what is text rather than script
 * depends on the syntax, and an "#if" is refused because the
 * compilers refuse it too.
 *
 * A free function for the reason cxx_headers_read_by() is one.
 * pconfigure asks this of a script when it writes the Makefile, and
 * under AUTORECONFIGURE pdeps asks it of the same script while make
 * runs; an include only one of them found is a prerequisite under one
 * build and not under the other.
 *
 * on_missed is pinclude's, and is how pdeps hears about the places a
 * file would shadow one of these: pconfigure scans every script again
 * whenever it runs, and has no need to. */
std::vector<std::string>
script_includes_read_by(const std::string& path,
                        const std::vector<std::string>& opts,
                        pinclude::syntax syntax,
                        const pinclude::missed_callback& on_missed = {});

/* BASH is the first language I have that doesn't need a compile
 * phase. */
class language_bash: public language {
public:
    typedef std::shared_ptr<language_bash> ptr;

public:
    language_bash(const std::vector<std::string>& compile_opts,
                  const std::vector<std::string>& link_opts)
    : language(compile_opts, link_opts)
    {}

    virtual ~language_bash(void) {}

public:
    /* language_bash is the parent of all the base-like languages, these
     * arguments allow children to override some internal functionality so they
     * can compile slightly differently. */
    virtual std::string
    default_compiler_command(const context::ptr& ctx __attribute__((unused)))
    const
        { return makefile::tool_command("pbashc"); }
    virtual std::string compiler_pretty(void) const { return "BASH"; }

    /* How the compiler reads a source, which is how the list of what
     * that source includes has to be found too.  The two have to
     * agree about which lines are text rather than script, or make
     * is told about a file other than the one that gets compiled. */
    virtual pinclude::syntax script_syntax(void) const
        { return pinclude::syntax::SHELL; }

    /* Lists all the dependencies of a bash-like file -- these can be any sort
     * of makefile target because they might have dependencies themselves.
     * The options are the ones the compiler is run with, since its "-I"
     * and "-D" decide which files an "#include" reads. */
    virtual std::vector<makefile::target::ptr>
    dependencies(const std::string& path,
                 const std::vector<std::string>& opts) const;

    /* Whether what a source includes is pasted into the output, which
     * is what makes the list worth following while the build runs
     * under AUTORECONFIGURE.  It is for pbashc and pperlc, which
     * paste; phc copies a header as it stands, so nothing the header
     * includes ends up inside what it installs. */
    virtual bool pastes_includes(void) const { return true; }

    /* A target here is made from exactly one SOURCES, and a second one
     * is refused by targets().  What the refusal calls the target and
     * what it says to write instead depend on what the compiler does
     * with that one file: pbashc and pperlc expand its "#include"s, so
     * the second file belongs in the first, while phc copies a header
     * as it stands and the second one needs a HEADERS of its own.
     * "first" and "second" are the SOURCES contexts, and "spelling" is
     * the name the first would have to "#include" the second by. */
    virtual std::string one_source_noun(void) const { return "script"; }
    virtual std::string
    second_source_advice(const context::ptr& first,
                         const context::ptr& second,
                         const std::string& spelling) const;

protected:
    /* The piece of Makefile that names what one script reads, for a
     * project that works that out while it builds: a rule that runs
     * pdeps over the script, to be included by the Makefile.  "target"
     * is the file the script is compiled into, which is what the
     * fragment hangs the includes off of, and "opts" are what the
     * compiler is run with. */
    makefile::target::ptr
    deps_script(const context::ptr& ctx,
                const context::ptr& child,
                const std::string& target,
                const std::vector<std::string>& opts) const;

    /* Whether targets() below has anything to write for this kind of
     * context.  Every BASH-like language builds through it, so a child
     * that answers can_process() on the file names alone has to ask
     * this too: otherwise a LIBRARIES or GENERATE whose sources happen
     * to have its extension is claimed, and the first anyone hears of
     * it is targets() giving up halfway through writing the Makefile,
     * instead of the "no language" error that names the Configfile
     * line.  BASH itself is narrower still -- it doesn't take HEADERS,
     * which are the whole point of language_h. */
    static bool targets_handle(const context::ptr& ctx);

public:
    /* The suffixes a source has to end in for BASH to claim it.  It is
     * a list of its own rather than a literal in can_process() because
     * one other question turns on it: whether a file is read as a
     * script, line for line the way pbashc reads it, or as C.  The
     * test-directive scan asks that before the source's context exists
     * to be offered to the languages, and syntax_of() below is how. */
    static const std::vector<std::string>& source_extensions(void);

    /* How a source at this path is read: as the script one of the
     * BASH-like languages claims it to be, or as C when none of them
     * does.  It asks every one of them (BASH and perl both), since a
     * '#' starts a comment in each and none of them has C's comments
     * or backslash-newlines, and the answer is the syntax rather than
     * a yes or no because the two still part over heredocs and Perl's
     * "__DATA__". */
    static pinclude::syntax syntax_of(const std::string& path);

public:
    /* Virtual methods from language. */
    virtual std::string name(void) const { return "bash"; }
    virtual language_bash* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
    virtual std::vector<makefile::target::ptr> targets(const context::ptr& ctx) const;

    /* A bash-like language links nothing: the sources are handed to
     * pbashc and what comes out is one file.  So there is no half of
     * AUTODEPS here for a "false" to be aimed at, and all it does is
     * stop the includes being prerequisites. */
    virtual bool autodeps_links(void) const { return false; }
};

#endif
