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

#ifndef LANGUAGES__C_CXX
#define LANGUAGES__C_CXX

#include "cxx.h++"
#include <memory>

/* The simplest language I support: C. */
class language_c: public language_cxx {
public:
    typedef std::shared_ptr<language_c> ptr;

public:
    /* Virtual methods from language_cxx. */
    virtual std::string compiler_command(void) const { return "${CC}";  }
    virtual std::string compiler_pretty (void) const { return "CC";     }
    virtual std::string linker_command  (void) const { return "${CC}";  }
    virtual std::string linker_pretty   (void) const { return "LD";     }

    /* Virtual methods from language. */
    virtual std::string name(void) const { return "c"; }
    virtual bool can_process(const context::ptr& ctx) const;
};

#endif
