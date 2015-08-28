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

#ifndef VECTOR_UTIL_HXX
#define VECTOR_UTIL_HXX

#include <vector>

template<class T>
static inline
std::vector<T> operator+(const std::vector<T>& a, const std::vector<T>& b)
{
    auto o = std::vector<T>();
    move(a.begin(), a.end(), std::back_inserter(o));
    move(b.begin(), b.end(), std::back_inserter(o));
    return o;
}

#endif
