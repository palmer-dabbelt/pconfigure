/*
 * Copyright (C) 2026 Palmer Dabbelt
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

#ifndef LANGUAGES__ASM_CXX
#define LANGUAGES__ASM_CXX

#include "c.h++"
#include <memory>

/* Assembly, in the spelling that goes through the C preprocessor
 * first: "*.S".  Nobody writes a program in nothing but that, so this
 * is C that can also compile a ".S" -- a target with a start file or a
 * context switch next to its C names both, and is linked the way a C
 * program is.  Everything else, from the dependency scan to the check
 * targets, is C's, which is to say language_cxx's. */
class language_asm: public language_c {
public:
    typedef std::shared_ptr<language_asm> ptr;

public:
    language_asm(const std::vector<std::string>& compile_opts,
                 const std::vector<std::string>& link_opts)
    : language_c(compile_opts, link_opts)
    {}

    virtual ~language_asm(void) {}

public:
    /* Virtual methods from language_cxx. */
    virtual std::string
    default_compiler_command(const context::ptr& ctx) const;
    virtual bool owns_source(const std::string& path) const;

    /* Virtual methods from language. */
    virtual std::string name(void) const { return "asm"; }
    virtual language_asm* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;

    /* Behind C, so that a target with nothing but ".c" in it is still
     * C's even in a project that turned this on: there it is C that
     * the target was written in, and asking which of two languages
     * that can both build it was meant would be a warning about a
     * choice nobody made. */
    virtual int priority(void) const { return 1; }
};

#endif
