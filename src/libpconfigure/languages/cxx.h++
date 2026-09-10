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
#include <memory>

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

    /* Hashes the link options that are relevant to this command's linking
     * (or compiling) phase. */
    std::string hash_link_options(const context::ptr& ctx) const;
    std::string hash_compile_options(const context::ptr& ctx) const;
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
                    const std::string linker_pretty);

        virtual ~link_target(void) {}

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
        const std::vector<std::string> _comments;

    public:
        cp_target(const std::string& target_path,
                  const std::string& pretty_path,
                  const target::ptr& source,
                  const install_target& install,
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
        const shared_target& is_shared
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
                                      const shared_target& is_shared) const;

    /* Lists the dependencies of a since source file. */
    std::vector<std::string> dependencies(
        const std::string& filename,
        const shared_target& is_shared,
        const std::vector<std::string>& compile_opts
    ) const;
};

#endif
