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

#include "pick_language.h++"
#include <iostream>

language::ptr pick_language(const command_processor::ptr& processor,
                            const context::ptr& context)
{
    auto valid_languages = std::vector<language::ptr>();

    for (const auto& language: processor->languages())
        if (language->can_process(context))
            valid_languages.push_back(language);

    std::stable_sort(begin(valid_languages),
                     end(valid_languages),
                     [](const language::ptr& a, const language::ptr& b)
                     {
                         return a->priority() < b->priority();
                     }
        );

    if (valid_languages.size() >= 2) {
        if (valid_languages[0]->priority() == valid_languages[1]->priority()) {
            std::cerr << "WARNING: Multiple valid languages for\n  "
                      << std::to_string(context->cmd->debug())
                      << "\nselecting the first one: "
                      << valid_languages[0]->name()
                      << "\n\n";
        }
    }

    if (valid_languages.size() == 0) {
        std::cerr << "ERROR: Unable to find language for "
                  << std::to_string(context->cmd->debug())
                  << "\n";
        std::cerr << context->as_tree_string("  ") << "\n";
        abort();
    }

    return valid_languages[0];
}
