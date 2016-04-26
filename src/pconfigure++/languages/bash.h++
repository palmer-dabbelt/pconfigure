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
#include <memory>

/* BASH is the first language I have that doesn't need a compile
 * phase. */
class language_bash: public language {
public:
    typedef std::shared_ptr<language_bash> ptr;

public:
    /* language_bash is the parent of all the base-like languages, these
     * arguments allow children to override some internal functionality so they
     * can compile slightly differently. */
    virtual std::string compiler_command(void) const { return "pbashc"; }
    virtual std::string compiler_pretty(void) const { return "BASH"; }

    /* Lists all the dependencies of a bash-like file -- these can be any sort
     * of makefile target because they might have dependencies themselves. */
    virtual std::vector<makefile::target::ptr> dependencies(const std::string& path) const;

public:
    /* Virtual methods from language. */
    virtual std::string name(void) const { return "bash"; }
    virtual language_bash* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
    virtual std::vector<makefile::target::ptr> targets(const context::ptr& ctx) const;
};

#endif
