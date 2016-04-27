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

#include "language_list.h++"
#include "languages/gen_proc.h++"
#include <iostream>

language_list::language_list(void)
    : _languages_lookup(),
      _languages_list()
{
    this->add(std::make_shared<language_gen_proc>(std::vector<std::string>{}, std::vector<std::string>{}));
}

void language_list::add(const language::ptr& lang)
{
    auto l = _languages_lookup.find(lang->name());
    if (l != _languages_lookup.end()) {
        std::cerr << "Language '"
                  << lang->name()
                  << "' added twice\n";
        abort();
    }

    _languages_lookup[lang->name()] = lang;
    _languages_list.push_back(lang);
}

language::ptr language_list::search(const std::string& name)
{
    auto l = _languages_lookup.find(name);
    if (l == _languages_lookup.end())
        return NULL;

    return l->second;
}

const language_list::ptr& language_list::global(void)
{
    static language_list::ptr _global;
    if (_global == nullptr) _global = std::make_shared<language_list>();
    return _global;
}

void language_list::global_add(const language::ptr& lang)
{
    return global()->add(lang);
}

language::ptr language_list::global_search(const std::string& name)
{
    return global()->search(name);
}
