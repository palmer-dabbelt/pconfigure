/*
 * Copyright (C) 2016 Palmer Dabbelt
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

#ifndef LANGUAGES__H_CXX
#define LANGUAGES__H_CXX

#include "bash.h++"

/* h is just bash, but with a different compiler. */
class language_h: public language_bash {
public:
    typedef std::shared_ptr<language_h> ptr;

public:
    language_h(const std::vector<std::string>& compile_opts,
                  const std::vector<std::string>& link_opts)
    : language_bash(compile_opts, link_opts)
    {}

public:
    /* Virtual methods from language_bash. */
    virtual std::string compiler_command(void) const { return "phc"; }
    virtual std::string compiler_pretty(void) const { return "H"; }
    virtual std::vector<makefile::target::ptr> targets(const context::ptr& ctx) const;

    /* Virtual methods from language. */
    virtual std::string name(void) const { return "h"; }
    virtual language_h* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
};

#endif
