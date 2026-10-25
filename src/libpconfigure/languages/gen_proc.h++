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

#ifndef LANGUAGES__GEN_PROC_CXX
#define LANGUAGES__GEN_PROC_CXX

#include "../language.h++"
#include <memory>
#include <string>
#include <utility>
#include <vector>

/* GEN_PROC is the first language I have that doesn't need a compile
 * phase. */
class language_gen_proc: public language {
public:
    typedef std::shared_ptr<language_gen_proc> ptr;

public:
    language_gen_proc(const std::vector<std::string>& compile_opts,
                      const std::vector<std::string>& link_opts)
    : language(compile_opts, link_opts)
    {}

    virtual ~language_gen_proc(void) {}

public:
    /* Virtual methods from language. */
    virtual std::string name(void) const { return "gen_proc"; }
    virtual language_gen_proc* clone(void) const;
    virtual bool can_process(const context::ptr& ctx) const;
    virtual std::vector<makefile::target::ptr> targets(const context::ptr& ctx) const;

public:
    /* Every file the rules for one GENERATE write besides its output,
     * each with the few words a diagnostic needs to say what it is.
     * They sit next to the output and are named after it, which means
     * nothing stops another GENERATE's output from having one of these
     * names -- so the project asks this list before writing any rules.
     * The rules and this list spell the names through the same
     * helpers, so that the two cannot drift apart. */
    static std::vector<std::pair<std::string, std::string>>
    scratch_files(const std::string& output);
};

#endif
