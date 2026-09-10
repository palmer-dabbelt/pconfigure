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

    /* The targets make reads rather than builds, which is what makes
     * them different from everything else here.  make brings an
     * included makefile up to date before it has finished reading the
     * build, using the rules it has in memory -- and those came out of
     * a Makefile that may itself be the thing that is out of date.  A
     * fragment that depends on something this build builds therefore
     * has that thing built out of stale rules, before the reconfigure
     * which would have corrected them is allowed to run.  It then
     * fails at whatever the old rules were wrong about, which for a
     * source file that has just been added is a link line that has
     * never heard of it.
     *
     * So a fragment is left to be remade out of what is already on
     * disk.  What that costs is that rebuilding the tool which writes
     * the fragments does not on its own rewrite them; a reconfigure
     * does, and one of those happens whenever the options a fragment
     * was written under change.  A build that cannot be run at all is
     * the worse of the two. */
    auto included = std::set<std::string>();
    for (const auto& target: targets)
        if (target->included() == true)
            included.insert(target->name());

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
        if (included.find(want.target) != included.end())
            continue;

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

#ifdef TEST_INCLUDED
/* Builds a target with a recipe, which is what makes it something the
 * build knows how to produce rather than a file that has to be there
 * already. */
static makefile::target::ptr built(const std::string& name,
                                   const std::string& cmd)
{
    return std::make_shared<makefile::target>(
        name,
        "TEST",
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        std::vector<std::string>{cmd},
        std::vector<std::string>{});
}

/* A fragment make includes has to come out of this with no dependency
 * on anything the build builds, because make brings it up to date out
 * of rules that may already be wrong.  The ordinary target is here so
 * that the check means something: without it this would pass just as
 * well against a function that had stopped matching anything at all. */
int main(void)
{
    auto tool = built("bin/tool", "cc -o bin/tool tool.c");
    auto fragment = built("obj/thing.d", "bin/tool --deps")->as_included();
    auto object = built("obj/thing.o", "bin/tool --compile");

    auto out = makefile::implied_deps(
        std::vector<makefile::target::ptr>{tool, fragment, object},
        std::vector<makefile::capability>{
            makefile::capability("file:bin/tool", "bin/tool")},
        std::vector<makefile::capability>{
            makefile::capability("file:bin/tool", "obj/thing.d"),
            makefile::capability("file:bin/tool", "obj/thing.o")});

    if (out.size() != 1)
        return 2;
    if (out[0].target != "obj/thing.o")
        return 3;
    if (out[0].dep != "bin/tool")
        return 4;

    return 0;
}
#endif
