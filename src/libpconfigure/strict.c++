/*
 * Copyright (C) 2026 Palmer Dabbelt
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

#include "strict.h++"
#include <cstdlib>
#include <iostream>

/* The release the edge cases below were first written down in, which
 * is therefore the strictness that promotes none of them.  Everything
 * older than this behaved the same way, so it's also the floor. */
static const auto oldest = strict(0, 12, 0);

strict::strict(void)
: _major(0),
  _minor(12),
  _patch(0)
{
}

strict strict::parse(const std::string& str, const debug_info::ptr& d)
{
    auto bad = [&](const std::string& why) {
        std::cerr << std::to_string(d) << "\n"
                  << "  STRICT wants a pconfigure version, and '" << str
                  << "' " << why << "\n"
                  << "  it's written the way a release is written:"
                  << " 'STRICT = v0.13'\n";
        abort();
    };

    /* A leading 'v' is how the releases are spelled and how anybody
     * reading a Configfile will write it; leaving it off is how the
     * same number is spelled everywhere else.  Both mean the release,
     * so both are read. */
    auto rest = str;
    if (rest.size() > 0 && (rest[0] == 'v' || rest[0] == 'V'))
        rest = rest.substr(1);

    if (rest.size() == 0)
        bad("has no version in it");

    /* Three numbers separated by dots, of which only the first has to
     * be there: a version with a component left off is that component
     * set to zero, which is what everybody already means by "v0.13". */
    unsigned parts[3] = {0, 0, 0};
    size_t part = 0;
    auto digits = false;

    for (size_t i = 0; i < rest.size(); ++i) {
        auto c = rest[i];

        if (c == '.') {
            if (digits == false)
                bad("has an empty component in it");
            if (++part > 2)
                bad("has more than three components in it");
            digits = false;
            continue;
        }

        if (c < '0' || c > '9')
            bad("isn't a number");

        /* Nothing anybody could write is anywhere near this, and a
         * version that silently wrapped would compare as older than
         * it looks -- which is the one way this could quietly turn
         * warnings back off. */
        if (parts[part] > (1u << 20))
            bad("is bigger than any release there will ever be");

        parts[part] = parts[part] * 10 + (unsigned)(c - '0');
        digits = true;
    }

    if (digits == false)
        bad("has an empty component in it");

    auto out = strict(parts[0], parts[1], parts[2]);

    /* Asking for a version older than the one the compatibility story
     * starts at is asking for the oldest behaviour there is, which is
     * what that version already means. */
    if (out.at_least(oldest) == false)
        return oldest;

    return out;
}

std::string strict::to_string(void) const
{
    auto out = "v" + std::to_string(_major) + "." + std::to_string(_minor);

    /* A release with no patch number on it is written without one,
     * since that's how the releases are named and therefore how
     * somebody copying this back into a Configfile expects to see
     * it.  Both spellings read back the same either way. */
    if (_patch != 0)
        out += "." + std::to_string(_patch);

    return out;
}

bool strict::at_least(const strict& that) const
{
    if (_major != that._major)
        return _major > that._major;
    if (_minor != that._minor)
        return _minor > that._minor;
    return _patch >= that._patch;
}

void strict::complain(const strict& since,
                      const debug_info::ptr& where,
                      const std::string& what,
                      const std::string& instead) const
{
    auto fatal = at_least(since);

    std::cerr << std::to_string(where) << "\n"
              << "  " << (fatal ? "error" : "warning") << ": " << what << "\n"
              << "  " << instead << "\n";

    if (fatal == true) {
        std::cerr << "  ('STRICT = " << to_string()
                  << "' is what makes this an error)\n";
        abort();
    }

    /* The version that turns this one into an error rather than the
     * version this project asked for: somebody who wants to be told
     * loudly needs the number to write down, and the number is a
     * property of the warning rather than of them. */
    std::cerr << "  ('STRICT = " << since.to_string()
              << "' makes this an error)\n";
}
