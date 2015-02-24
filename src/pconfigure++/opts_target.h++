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

#ifndef OPTS_TARGET_HXX
#define OPTS_TARGET_HXX

#include <memory>
#include <vector>
#include <string>

/* There's a few things that can be a target for {COMPILE,LINK}OPTS
 * commands, this provides a unified interface that lets me store a
 * single pointer to whatever those should target so I don't have to
 * have special cases floating around everywhere. */
class opts_target {
public:
    typedef std::shared_ptr<opts_target> ptr;

public:
    /* These all do pretty much what they say on the tin -- add
     * something to the relevant options field. */
    virtual void add_compileopt(const std::string& data) = 0;
    virtual void add_linkopt(const std::string& data) = 0;
};

#endif
