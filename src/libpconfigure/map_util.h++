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

#ifndef MAP_UTIL_HXX
#define MAP_UTIL_HXX

namespace map_util {
    /* Allows std::multimap to be iterated. */
    template<typename I>
    class range {
    private:
        I _begin;
        I _end;

    public:
        range(const I& begin, const I& end)
            : _begin(begin),
              _end(end)
            {}

        range(const std::pair<I, I>& pair)
            : _begin(pair.first),
              _end(pair.second)
            {}

    public:
        const I& begin(void) const { return _begin; }
        const I& end  (void) const { return _end  ; }
    };

    template<typename I> range<I> to_range(const std::pair<I, I>& pair)
    { return range<I>(pair); }

    template<typename M, typename L>
    auto equal_range(const M& map, const L& l) ->
        decltype(to_range(map.equal_range(l)))
    {
        return to_range(map.equal_range(l));
    }

    /* Sometimes I want to store true/false in a map, where "false" is
     * returned when there isn't a match. */
    template<typename M, typename K>
    bool true_map(const M& m, const K& k)
    {
        auto l = m.find(k);
        if (l == m.end())
            return false;
        return l->second;
    }
}

#endif
