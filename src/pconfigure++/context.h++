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

#ifndef CONTEXT_HXX
#define CONTEXT_HXX

#include <memory>

/* The super-entry for a context.  There will be one of these contexts
 * for everything the build system knows about.  This pretty much
 * duplicates the design of the original C code (and therefor the
 * Configfile language): the state of the system consists of a stack
 * of these contexts, most commands modify the state of that stack
 * (some effect global variables). */
class context {
public:
    typedef std::shared_ptr<context> ptr;

public:
    /* Yes, that's right -- there's public data here!  Essentially a
     * context is just a big structure where anything can change at
     * any time, so it kind of makes sense... */

    /* The location into which the resulting files will be
     * installed. */
    std::string prefix;

public:
    /* Creates a new context with everything filled in to the default
     * values.  Note that you probably don't want to use this unless
     * you're creating a new context stack, you really want to
     * clone a context and then modify it. */
    context(void);
};

#endif
