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

#ifndef LANGUAGES__PHONY_HXX
#define LANGUAGES__PHONY_HXX

#include "../language.h++"

/* A target that is a name and nothing else, which is what a PHONY
 * asks for.
 *
 * This isn't a language in the sense the others are -- there's no
 * file to compile and no compiler to run -- but it is one in the
 * sense that matters here: something has to turn a context into
 * targets, and the tests hanging off a PHONY need somebody to ask
 * their own languages on their behalf.  Every project has this one
 * available without saying so, since asking for a name by name isn't
 * something a project should have to declare it can do. */
class language_phony: public language {
public:
    typedef std::shared_ptr<language_phony> ptr;

public:
    language_phony(const std::vector<std::string>& compile_opts,
                   const std::vector<std::string>& link_opts)
    : language(compile_opts, link_opts)
    {}

    virtual ~language_phony(void) {}

public:
    /* Virtual methods from language. */
    virtual std::string name(void) const { return "phony"; }
    virtual language_phony* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
    virtual std::vector<makefile::target::ptr>
    targets(const context::ptr& ctx) const;
};

#endif
