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

#ifndef LANGUAGES__CXX_CXX
#define LANGUAGES__CXX_CXX

#include "../language.h++"
#include <map>
#include <memory>
#include <pinclude.h++>

/* Every name a C or C++ source file goes by, and every name a header
 * that pairs with one goes by.  Which spelling a project picked is
 * its own business, and pconfigure has to know all of them: the
 * source that implements a header is found by taking the header's
 * name apart, and a project that never wrote either name down still
 * expects that to work.
 *
 * ".c" is missing from the source list on purpose.  That one belongs
 * to C, and keeping it out of here is the whole of what stops the two
 * languages from both claiming the same file. */
const std::vector<std::string>& cxx_source_extensions(void);
const std::vector<std::string>& cxx_header_extensions(void);

/* The sources that implement a header, which is every file that
 * exists whose name is that header's with a source ending on it.
 *
 * This is a free function rather than a method because the answer is
 * a property of the names C and C++ go by rather than of a language
 * object: whoever is deciding what to build against a header wants
 * the same answer, and the one place it can be wrong is a place two
 * copies of it would eventually disagree about. */
std::vector<std::string>
cxx_sources_for_header(const std::string& full_header_path);

/* The include directories and the defines a compiler command line
 * asks for, read the way the compiler reads them.
 *
 * Every flag that adds a directory to the search counts: "-I",
 * "-isystem", "-iquote", "-idirafter" and clang's "-isystem-after"
 * all decide where a "#include" is found, so a header in any of them
 * is one the object was compiled against.  They come back in the
 * order the compiler searches them, which is by kind and not by the
 * order they were written in, with the "-iquote" ones set apart for
 * the quoted spelling alone.  Each of them, and "-D", may have its
 * argument stuck on or as the word after it.  The options are words
 * already -- a line of COMPILEOPTS split on its spaces -- which is
 * what compile_options() hands out.
 *
 * Free functions for the same reason cxx_sources_for_header() is one:
 * pconfigure asks this question of a source when it writes the
 * Makefile and pdeps asks it of the same source while make runs, and
 * a header only one of them found is a header that is a prerequisite
 * under one build and not under the other. */
pinclude::search_path
cxx_include_search(const std::vector<std::string>& opts);
std::vector<std::string>
cxx_defines(const std::vector<std::string>& opts);

/* The headers a source reads when it is compiled with the given
 * options, which comes down to the include path and the defines those
 * options would hand the preprocessor, and the files "-include" and
 * "-imacros" have it read before the source -- which are headers of
 * the source themselves, and whose own defines the source then sees.
 *
 * This is asked in two places -- by pconfigure when it walks the
 * sources itself, and by pdeps when make does the walking under
 * AUTORECONFIGURE -- and it used to be answered by two copies of the
 * same loop.  Each copy got the same things wrong in the same way, so
 * the fix had to be made twice; now it only has to be made here, and
 * the two can't come to disagree about which headers a source reads.
 *
 * "promised" is the headers the build is going to make, which pdeps
 * passes and pconfigure does not: pconfigure has made every one of
 * them by the time it scans anything, and pdeps can be asked after a
 * "make clean" has taken them all away again.
 *
 * "on_missed" is pinclude's, spelled the way the headers are, and is
 * pdeps's too: it is how a fragment learns where a new header would
 * shadow one of these, which pconfigure never needs to be told
 * because it scans every source again whenever it runs. */
std::vector<std::string>
cxx_headers_read_by(const std::string& source,
                    const std::vector<std::string>& compile_opts,
                    const std::vector<std::string>& promised = {},
                    const pinclude::missed_callback& on_missed = {});

/* The endings that search tries, which is what anything deciding
 * how to build what it finds has to have an answer for. */
const std::vector<std::string>& cxx_header_source_extensions(void);

/* C++ is probably the best supported of the pconfigure language
 * implementations, as it's the one that pconfigure itself is written
 * in. */
class language_cxx: public language {
public:
    typedef std::shared_ptr<language_cxx> ptr;

public:
    language_cxx(const std::vector<std::string>& compile_opts,
                 const std::vector<std::string>& link_opts)
    : language(compile_opts, link_opts)
    {}

    virtual ~language_cxx(void) {}

public:
    /* Allows sub-classes of this language to override the compiler and linker
     * strings. */
    virtual std::string
    default_compiler_command(const context::ptr& ctx) const;
    virtual std::string compiler_pretty (void) const { return "C++";    }
    virtual std::string
    default_linker_command(const context::ptr& ctx) const;
    virtual std::string linker_pretty   (void) const { return "LD++";   }

public:
    /* TRUE when a source with this name is one this language
     * compiles.  It is asked about the sources found behind a header,
     * which nobody named and which therefore don't come with a
     * language attached: a ".c++" sitting next to a header a C source
     * includes is still C++, and has to be compiled as C++. */
    virtual bool owns_source(const std::string& path) const;

    /* TRUE when this language compiles a source with this name that
     * it finds behind one of its own target's headers, rather than
     * handing it to the language that owns it.  That is everything it
     * owns, and for C++ it is C as well: compiling a C library's
     * sources a second time as C++, into a C++ library whose header
     * wraps the same declarations in a namespace, is something
     * projects do on purpose (gitdate.bash) and something a C header
     * without an 'extern "C"' (multi-language-build.bash) only links
     * from C++ by.  C can't compile C++, so a ".c++" behind a C
     * program's header still goes to C++. */
    virtual bool keeps_source(const std::string& path) const;

    /* Virtual methods from language. */
    virtual std::string name(void) const { return "c++"; }
    virtual language_cxx* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
    virtual std::vector<makefile::target::ptr> targets(const context::ptr& ctx) const;
    virtual std::vector<std::string>
    provides(const makefile::target::ptr& target) const;
    virtual std::vector<std::string>
    needs(const makefile::target::ptr& target) const;

protected:
    /* This function allows subclasses to override dependency handling: it
     * takes the full path to a header file, and produces the full path to any
     * source files that might need to be compiled and linked as part of that.
     * */
    virtual std::vector<std::string>
    find_files_for_header(const std::string& full_header_path) const;

private:
    /* This helper function returns TRUE if the context should generated shared
     * targets. */
    enum class shared_target {
        FALSE,
        TRUE,
    };
    shared_target is_shared_target(const context::ptr& ctx) const;

    /* What to run to put an archive together.  It's the same question
     * as which compiler to run, with the same answer for a cross
     * build: a toolchain's "ar" carries its prefix like everything
     * else in it does. */
    std::string archiver_command(const context::ptr& ctx) const;

    /* Passed to target generation functions to indicate if this target should
     * be built for installation, or should be built for local usage. */
    enum class install_target {
        FALSE,
        TRUE,
    };

    /* The command line one source gets compiled with, which is the
     * project's options rerooted onto wherever this project's sources
     * are plus the handful pconfigure adds itself.
     *
     * It is worked out in one place because two things need it and
     * have to agree: the rule that compiles the source, and the file
     * that says which headers the source reads.  A "-I" that only one
     * of them knew about is a header that is found by the compiler and
     * is not a prerequisite of anything. */
    std::vector<std::string> compile_options(const context::ptr& ctx,
                                             const context::ptr& child) const;

    /* Where what this target builds ends up, and the directory the
     * link steps for it go in.  Both are named from more than one
     * place, and a second spelling of either is a build putting files
     * somewhere nothing looks for them. */
    std::string output_dir(const context::ptr& ctx) const;
    std::string link_dir(const context::ptr& ctx) const;

    /* Which language compiles each of the sources that can turn up
     * behind a header, keyed by the ending that says so.
     *
     * The sources a target was told about are all in its own
     * language, because that's how its language was picked.  The ones
     * found behind its headers are whatever the files next to those
     * headers happen to be called, and C and C++ share their headers,
     * so a C program can reach a ".c++" and a C++ one a ".c".  The
     * target's own language keeps whatever keeps_source() says it
     * can compile, which for C++ includes C; anything else is
     * compiled by the language whose file it is, from whichever ones
     * the project enabled -- and by the target's own language when
     * none of them claims it, there being nothing else to hand it
     * to.
     *
     * Worked out once per target and handed down the whole walk,
     * because the walk crosses languages: the answer has to be the
     * same from a C++ source as it is from the C source it led to, or
     * one file is compiled twice under two names. */
    struct behind_languages:
        public std::map<std::string, const language_cxx*>
    {
        /* The target's own language, which is the one its COMPILER
         * was said to.  Kept with the map because that is what goes
         * down the walk, and every step of the walk has to know it
         * -- see foreign_context(). */
        const language_cxx* target = nullptr;
    };
    behind_languages languages_behind_headers(const context::ptr& ctx) const;

    /* Hashes the link options that are relevant to this command's linking
     * (or compiling) phase. */
    std::string hash_link_options(const context::ptr& ctx) const;
    std::string hash_compile_options(const context::ptr& ctx,
                                     const context::ptr& child) const;
    std::vector<std::string> lib_dir_link_options(const context::ptr& ctx) const;
    std::vector<std::string> dep_lib_link_options(const context::ptr& ctx) const;
    std::vector<std::string> added_link_options(const context::ptr& ctx) const;
    std::vector<std::string> unbased_options(const context::ptr& ctx,
                                             const std::vector<std::string>& opts) const;
    std::string hash_options(const std::vector<std::string>& opts) const;

protected:
    /* The sub-class that represents a C++ specific target. */
    class target {
    public:
        typedef std::shared_ptr<target> ptr;

    public:
        virtual makefile::target::ptr generate_makefile_target(void) const = 0;
        virtual std::string path(void) const = 0;
    };

    /* This sort of target links together a bunch of object files, producing a
     * binary. */
    class link_target: public target {
    private:
        const std::string _target_path;
        const std::vector<target::ptr> _objects;
        const std::vector<target::ptr> _additional_deps;
        const install_target _install;
        const shared_target _shared;
        const std::vector<std::string> _comments;
        const std::vector<std::string> _opts;
        const context::ptr _ctx;
        const std::string _linker_command;
        const std::string _linker_pretty;

        /* Where the hash of this link's inputs lives, from
         * link_objects().  It rides the rule as one more
         * prerequisite, because a link input that leaves changes the
         * file without touching anything else make watches. */
        const std::string _link_inputs_path;

    public:
        link_target(const std::string& target_path,
                    const std::vector<target::ptr>& objects,
                    const std::vector<target::ptr>& additional_deps,
                    const install_target& install,
                    const shared_target& shared,
                    const std::vector<std::string>& comments,
                    const std::vector<std::string>& opts,
                    const context::ptr& ctx,
                    const std::string linker_command,
                    const std::string linker_pretty,
                    const std::string link_inputs_path);

        virtual ~link_target(void) {}

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _target_path; }
    };

    /* This sort of target archives a bunch of object files, producing
     * a static library.  It's a link_target with nearly everything
     * taken away: an archive has no link line, so there's nowhere for
     * link options, rpaths or a soname to go, and nothing about it
     * differs between the copy that gets installed and the one that
     * gets used in the tree. */
    class archive_target: public target {
    private:
        const std::string _target_path;
        const std::vector<target::ptr> _objects;
        const std::vector<std::string> _comments;
        const context::ptr _ctx;
        const std::string _archiver_command;
        const std::string _archiver_pretty;

        /* The same hash of the inputs that a link_target rides on,
         * for the same reason: an object leaving the archive has to
         * rebuild it. */
        const std::string _link_inputs_path;

    public:
        archive_target(const std::string& target_path,
                       const std::vector<target::ptr>& objects,
                       const std::vector<std::string>& comments,
                       const context::ptr& ctx,
                       const std::string archiver_command,
                       const std::string archiver_pretty,
                       const std::string link_inputs_path);

        virtual ~archive_target(void) {}

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _target_path; }
    };

    /* This sort of target compiles a single file, producing  */
    class compile_target: public target {
    private:
        const std::string _target_path;
        const std::string _main_source;
        const shared_target _shared;
        const std::vector<std::string> _comments;
        const std::vector<std::string> _opts;
        const context::ptr _ctx;
        const std::vector<target::ptr> _header_deps;
        const std::string _compiler_command;
        const std::string _compiler_pretty;

    public:
        compile_target(const std::string& target_path,
                       const std::string& _main_source,
                       const shared_target& shared,
                       const std::vector<std::string>& comments,
                       const std::vector<std::string>& opts,
                       const context::ptr& ctx,
                       const std::vector<target::ptr>& header_deps,
                       const std::string compiler_command,
                       const std::string compiler_pretty);

        virtual ~compile_target(void) {}

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _target_path; }
    };

    /* This sort of target just copies from the source to the destination. */
    class cp_target: public target {
    private:
        const std::string _target_path;

        /* What to call the file when telling somebody it's being
         * copied.  The path this ends up at is relative to wherever
         * pconfigure ran, which isn't a name a subproject's own build
         * would recognize. */
        const std::string _pretty_path;
        const target::ptr _source;
        const install_target _install;

        /* The mode an installed copy is given, as "install -m" would
         * take it: "0755" for what gets run or loaded, "0644" for a
         * static archive, which is only ever read.  A copy into the
         * build tree keeps whatever mode it was made with. */
        const std::string _install_mode;
        const std::vector<std::string> _comments;

    public:
        cp_target(const std::string& target_path,
                  const std::string& pretty_path,
                  const target::ptr& source,
                  const install_target& install,
                  const std::string& install_mode,
                  const std::vector<std::string> comments);

        virtual ~cp_target(void) {}

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _target_path; }
    };

    /* This sort of target actually does _nothing_, it just serves as a standin
     * for dependencies that already exist. */
    class header_target: public target {
    private:
        const std::string _path;

    public:
        header_target(const std::string& path);
	virtual ~header_target(void) {}

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _path; }
    };

    /* Links together a bunch of object files into the target binary or
     * library. */
    std::vector<target::ptr> link_objects(
        const context::ptr& ctx,
        const std::vector<target::ptr>& objects
    ) const;

    /* Compiles a source file into an object, returns the compiled target
     * along with all dependencies of this target. */
    std::vector<target::ptr> compile_source(
        const context::ptr& ctx,
        const context::ptr& child,
        std::vector<std::string>& already_processed,
        const shared_target& is_shared,
        const behind_languages& behind
    ) const;

    /* The piece of Makefile that says what one source depends on,
     * which is what a project that asked for AUTORECONFIGURE gets
     * instead of a compile rule with the answer already in it.
     *
     * Nothing is scanned here.  What comes back is a target that runs
     * pdeps, and a context file written beside it saying what pdeps
     * needs to know -- so the walk that compile_source() does with a
     * function calling itself is done by make, reading one of these
     * after another. */
    makefile::target::ptr deps_source(const context::ptr& ctx,
                                      const context::ptr& child,
                                      const shared_target& is_shared,
                                      const behind_languages& behind) const;

    /* The pieces deps_source() is made of, split out because the
     * context file it writes has to name other sources' fragments and
     * other options' context files, spelled exactly the way their own
     * rules spell them.  Each language writes its own context file,
     * which is what lets a walk that crosses from one into another go
     * on in the right one; the link they all name is the target's,
     * and so are the named sources' fragments, both of which
     * deps_source() works out once and hands down. */
    std::string deps_suffix(const context::ptr& ctx,
                            const context::ptr& child,
                            const std::string& link,
                            const shared_target& is_shared) const;
    std::string deps_path(const context::ptr& ctx,
                          const context::ptr& child,
                          const std::string& link,
                          const shared_target& is_shared) const;
    std::string deps_context_path(const context::ptr& ctx,
                                  const context::ptr& child,
                                  const std::string& link) const;
    std::string write_deps_context(const context::ptr& ctx,
                                   const context::ptr& child,
                                   const std::string& link,
                                   const shared_target& is_shared,
                                   const behind_languages& behind,
                                   const std::string& named) const;

    /* The context a source found behind a header is built in, which is
     * the target's rather than that of the source whose header it
     * was. */
    context::ptr behind_header_context(const context::ptr& ctx,
                                       const std::string& name,
                                       const debug_info::ptr& debug) const;

    /* The context the language "owner" compiles a source found behind
     * one of this target's headers in: the one it was handed, less the
     * target's COMPILER when the owner isn't the target's language. */
    static context::ptr foreign_context(const context::ptr& plain,
                                        const language_cxx* owner,
                                        const behind_languages& behind);

    /* Lists the dependencies of a since source file. */
    std::vector<std::string> dependencies(
        const std::string& filename,
        const shared_target& is_shared,
        const std::vector<std::string>& compile_opts
    ) const;
};

#endif
