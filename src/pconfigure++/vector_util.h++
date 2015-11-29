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
#include <sstream>

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
    /* A functional map: returns a vector with the given function called for
     * every element. */
    template<typename V, typename F>
    static inline
    auto map(const V& v, F f)
        -> std::vector<decltype(f(std::declval<typename V::value_type>()))>
    {
        std::vector<decltype(f(std::declval<typename V::value_type>()))> o;
        std::transform(v.begin(), v.end(), std::back_inserter(o), f);
        return o;
    }

    /* A functional filter: returns the elements for which the given function
     * returns true. */
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

    /* Forces a cast between vectors of two different sub-types.  This relies
     * on an implicit conversion existing between the two types stored within
     * the vector. */
    template<typename T, typename F>
    static inline
    std::vector<T> cast(const std::vector<F>& in)
    {
        return map(in, [](F f) -> T { return f; });
    }

    /* Joins a vector together. */
    static inline
    std::string join(const std::vector<std::string>& v, std::string sep = " ")
    {
        if (v.size() == 0)
            return "";

        std::stringstream out;
        out << v[0];
        for (size_t i = 0; i < v.size(); ++i)
            out << sep << v[i];
        return out.str();
    }

    /* Creates a vector of one element, without the need for any types. */
    template<typename E>
    static inline
    std::vector<E> make(const E& e)
    {
        return std::vector<E>{e};
    }
}

#endif
