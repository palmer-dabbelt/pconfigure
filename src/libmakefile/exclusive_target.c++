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

#include "exclusive_target.h++"
#include <map>
using namespace makefile;

template<typename I>
class range {
private:
    I _begin;
    I _end;

public:
    range(const I& begin, const I& end)
        : _begin(begin),
          _end(end)
        {}

    range(const std::pair<I, I>& pair)
        : _begin(pair.first),
          _end(pair.second)
        {}

public:
    const I& begin(void) const { return _begin; }
    const I& end  (void) const { return _end  ; }
};

template<typename I> range<I> to_range(const std::pair<I, I>& pair)
{ return range<I>(pair); }

static std::multimap <std::string, std::string> exclusive_list;

static inline
std::vector<target::ptr> add_deps(const std::vector<target::ptr>& deps,
                                  const std::string& key,
                                  const std::string& name);

exclusive_target::exclusive_target(const std::string& key,
                                   const std::string& name,
                                   const std::string& short_cmd,
                                   const std::vector<target::ptr>& deps,
                                   const std::vector<global_targets>& global,
                                   const std::vector<std::string>& cmds,
                                   const std::vector<std::string>& comment)
    : target(name,
             short_cmd,
             add_deps(deps, key, name),
             global,
             cmds,
             comment)
{
}

std::vector<target::ptr> add_deps(const std::vector<target::ptr>& deps,
                                  const std::string& key,
                                  const std::string& name)
{
    std::vector<target::ptr> out;

    for (const auto& dep: deps)
        out.push_back(dep);

    out.push_back(std::make_shared<target>("|"));

    for (const auto& dep: to_range(exclusive_list.equal_range(key)))
        out.push_back(std::make_shared<target>(dep.second));

    exclusive_list.insert({key, name});

    return out;
}
