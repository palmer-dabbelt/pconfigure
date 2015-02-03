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

#ifndef LANGUAGE_LIST_HXX
#define LANGUAGE_LIST_HXX

#include <memory>
#include <vector>
#include <map>
#include "language.h++"

/* Contains the list of languages that can be supported by  */
class language_list {
public:
    typedef std::shared_ptr<language_list> ptr;

private:
    std::map<std::string, language::ptr> _languages;

public:
    /* Creates a new language list without any languages in it at
     * all! */
    language_list(void);

public:
    /* Adds a new language to this list. */
    void add(const language::ptr& lang);

    /* Searches through this language list for a matching item. */
    language::ptr search(const std::string& name);

public:
    /* There's also a global list of languages, which is where every
     * language in the system ends up registered.  These functions
     * just redirect to that global list. */
    static void global_add(const language::ptr& lang);
    static language::ptr global_search(const std::string& name);
};

#endif
