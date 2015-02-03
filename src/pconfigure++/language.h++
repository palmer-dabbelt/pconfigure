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

#ifndef LANGUAGE_HXX
#define LANGUAGE_HXX

#include <memory>

/* Contains a single language. */
class language {
public:
    typedef std::shared_ptr<language> ptr;

private:

public:

public:
    /* Returns the name of this language, which is used as a unique
     * key when users refer to it from Configfiles. */
    virtual std::string name(void) const = 0;

    /* Returns a deep copy of this language, such that modifications
     * of the returned language will not effect this language.  Note
     * that this has to return a regular pointer (and not a
     * shared_ptr) because C++11 doesn't support covariant return
     * types. */
    virtual language* clone(void) const = 0;
};

#endif
