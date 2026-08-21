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

#include "project.h++"
#include "pick_language.h++"
#include <iostream>

project::project(const std::string& base,
                 const command_processor::ptr& processor)
: _base(base),
  _processor(processor)
{
}

void project::generate_targets(void)
{
    for (const auto& context: _processor->output_contexts()) {
        if (context->debug == true)
            std::cerr << "Building Context: " << context->cmd->data() << "\n";

        auto language = pick_language(context->languages, context);
        for (const auto& target: language->targets(context)) {
            auto found = _by_name.find(target->name());
            if (found == _by_name.end()) {
                if (context->debug == true)
                    std::cerr << "  target: " << target->name() << "\n";
                _targets.push_back(target);
            } else if (!same_recipe(found->second, target)) {
                std::cout << "Mismatched recipe for targets with same name\n";
                abort();
            }
            _by_name[target->name()] = target;

            /* Only the language that wrote this recipe knows how to
             * read it, so it's the one that says what this target
             * offers and what it wants.  Matching those up is left
             * until every project's targets are known. */
            for (const auto& name: language->provides(target))
                _provided.push_back(makefile::capability(name, target->name()));
            for (const auto& name: language->needs(target))
                _needed.push_back(makefile::capability(name, target->name()));
        }
    }
}

makefile::target::ptr project::cache_clean_target(void) const
{
    auto obj_dirs = std::map<std::string, bool>();
    for (const auto& context: _processor->output_contexts())
        obj_dirs[context->obj_dir] = true;

    auto commands = std::vector<std::string>();
    for (const auto& pair: obj_dirs) {
        const auto& dir = pair.first;
        commands.push_back(
            "comm -23 "
            "<(find " + dir + " -type f | sort) "
            "<(sed -n 's/\\(^" + dir + "\\/[^[:space:]:]*\\):.*/\\1/p' "
            + makefile_path() + " | sort -u) "
            "| xargs -r rm -f"
        );
        commands.push_back("find " + dir + " -type d -empty -delete");
    }

    return std::make_shared<makefile::target>(
        "cache-clean",
        "CACHE-CLEAN",
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        commands,
        std::vector<std::string>{"cache-clean"}
    );
}

makefile::target::ptr project::distclean_target(void) const
{
    auto dirs = std::map<std::string, bool>();
    for (const auto& context: _processor->output_contexts()) {
        dirs[context->bin_dir] = true;
        dirs[context->check_dir] = true;
        dirs[context->lib_dir] = true;
        dirs[context->obj_dir] = true;
    }

    auto commands = std::vector<std::string>();
    for (const auto& pair: dirs)
        commands.push_back("rm -rf " + pair.first);
    commands.push_back("rm -rf " + makefile_path());

    return std::make_shared<makefile::target>(
        "distclean",
        "DISTCLEAN",
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        commands,
        std::vector<std::string>{"distclean"}
    );
}

void project::write_makefile(const std::vector<makefile::implied_dep>& implied) const
{
    /* FIXME: If any target is verbose, then all are. */
    auto verbose = [&](void) -> bool {
        for (const auto& context: _processor->output_contexts())
            if (context->verbose == true)
                return true;
        return false;
        }();

    auto out = std::make_shared<makefile::makefile>(
        verbose,
        _processor->root_context()->obj_dir);

    for (const auto& target: _targets)
        out->add_target(target);

    for (const auto& dep: implied)
        if (_by_name.find(dep.target) != _by_name.end())
            out->add_dep(dep.target, dep.dep);

    out->add_standalone_target(cache_clean_target());
    out->add_standalone_target(distclean_target());

    out->write_to_file(makefile_path());
}
