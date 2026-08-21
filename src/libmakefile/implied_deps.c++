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

#include "implied_deps.h++"
#include <map>
#include <set>

std::vector<makefile::implied_dep>
makefile::implied_deps(const std::vector<target::ptr>& targets,
                       const std::vector<capability>& provided,
                       const std::vector<capability>& needed)
{
    /* Everything that something knows how to build.  A target with no
     * commands is just a stand-in for a file that already exists, so
     * depending on it wouldn't cause anything to be built. */
    auto buildable = std::set<std::string>();
    for (const auto& target: targets)
        if (target->cmds().size() > 0)
            buildable.insert(target->name());

    auto providers = std::map<std::string, std::vector<std::string>>();
    for (const auto& capability: provided)
        if (buildable.find(capability.target) != buildable.end())
            providers[capability.name].push_back(capability.target);

    /* The dependencies that are already written down, which is both
     * how duplicates are avoided and how cycles are detected. */
    auto deps = std::map<std::string, std::set<std::string>>();
    for (const auto& target: targets)
        for (const auto& dep: target->deps())
            deps[target->name()].insert(dep->name());

    /* Returns TRUE if "from" already depends on "to", directly or
     * otherwise -- which means an edge the other way around would
     * produce a cycle. */
    auto reaches = [&](const std::string& from, const std::string& to) {
        auto seen = std::set<std::string>();
        auto stack = std::vector<std::string>{from};
        while (stack.size() > 0) {
            auto node = stack.back();
            stack.pop_back();
            if (node == to)
                return true;
            if (seen.insert(node).second == false)
                continue;
            auto found = deps.find(node);
            if (found == deps.end())
                continue;
            for (const auto& next: found->second)
                stack.push_back(next);
        }
        return false;
    };

    auto out = std::vector<implied_dep>();
    for (const auto& want: needed) {
        auto found = providers.find(want.name);
        if (found == providers.end())
            continue;

        for (const auto& provider: found->second) {
            if (provider == want.target)
                continue;
            if (deps[want.target].find(provider) != deps[want.target].end())
                continue;
            if (reaches(provider, want.target) == true)
                continue;

            deps[want.target].insert(provider);
            out.push_back(implied_dep(want.target, provider));
        }
    }

    return out;
}
