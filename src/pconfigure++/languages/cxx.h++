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

/* C++ is probably the best supported of the pconfigure language
 * implementations, as it's the one that pconfigure itself is written
 * in. */
class language_cxx: public language {
public:
    typedef std::shared_ptr<language_cxx> ptr;

public:
    /* Virtual methods from language. */
    virtual std::string name(void) const { return "c++"; }
    virtual language_cxx* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
    virtual std::vector<makefile::target::ptr> targets(const context::ptr& ctx) const;

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
        const install_target _install;
        const shared_target _shared;
        const std::vector<std::string> _comments;
        const context::ptr _ctx;

    public:
        link_target(const std::string& target_path,
                    const std::vector<target::ptr>& objects,
                    const install_target& install,
                    const shared_target& shared,
                    const std::vector<std::string>& comments,
                    const context::ptr& ctx);

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _target_path; }
    };

    /* This sort of target just copies from the source to the destination. */
    class cp_target: public target {
    private:
        const std::string _target_path;
        const target::ptr _source;
        const install_target _install;
        const std::vector<std::string> _comments;

    public:
        cp_target(const std::string& target_path,
                  const target::ptr& source,
                  const install_target& install,
                  const std::vector<std::string> comments);

    public:
        /* target virtual functions */
        virtual makefile::target::ptr generate_makefile_target(void) const;
        virtual std::string path(void) const { return _target_path; }
    };

    /* Links together a bunch of object files into the target binary or
     * library. */
    std::vector<target::ptr> link_objects(const context::ptr& ctx,
                                          const std::vector<target::ptr>& objects)
                                          const;
                                          
};

#endif
