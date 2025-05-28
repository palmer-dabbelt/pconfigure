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

#ifndef LANGUAGES__SWIG_CXX
#define LANGUAGES__SWIG_CXX

#include "cxx.h++"
#include <memory>

/* SWIG generates shared libraries from C code, but with wrappers so they can
 * be loaded into various other languages. */
class language_swig: public language_cxx {
public:
    typedef std::shared_ptr<language_swig> ptr;

public:
    language_swig(const std::vector<std::string>& compile_opts,
                  const std::vector<std::string>& link_opts)
    : language_cxx(compile_opts, link_opts)
    {}

    virtual ~language_swig(void) {}

public:
    /* Virtual methods from language_swigxx. */
    virtual std::string compiler_command(void) const { return "pswigcc --cc=$(CXX)"; }
    virtual std::string compiler_pretty (void) const { return "SWCC";     }
    virtual std::string linker_command  (void) const { return "$(CXX)";  }
    virtual std::string linker_pretty   (void) const { return "SWLD";     }

    /* Virtual methods from language. */
    virtual std::string name(void) const { return "swig"; }
    virtual language_swig* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
};

#endif
