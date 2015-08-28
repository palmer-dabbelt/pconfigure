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

#include <algorithm>
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

namespace vector_util {
    template<typename V, typename F>
    static inline
    auto map(const V& v, F f)
        -> std::vector<decltype(f(std::declval<typename V::value_type>()))>
    {
        std::vector<decltype(f(std::declval<typename V::value_type>()))> o;
        std::transform(v.begin(), v.end(), std::back_inserter(o), f);
        return o;
    }

    template<typename V, typename F>
    static inline
    auto filter(const V& v, F f)
        -> std::vector<typename V::value_type>
    {
        std::vector<typename V::value_type> o;
        for (const auto& e: v)
            if (f(e))
                o.push_back(e);
        return o;
    }
}

#endif
