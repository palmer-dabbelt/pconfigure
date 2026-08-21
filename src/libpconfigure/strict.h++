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

#ifndef STRICT_HXX
#define STRICT_HXX

#include "debug_info.h++"
#include <string>

/* How much of what pconfigure used to let a project get away with it
 * should still let it get away with.
 *
 * A handful of Configfile lines are accepted and then quietly do
 * something nobody meant.  None of them can simply be made errors:
 * every one of them is something a project somewhere is relying on
 * without knowing it, and a build system that stops building last
 * week's project is not much of a build system.  So they're warnings,
 * and a project that would rather be told loudly says so:
 *
 *     STRICT = v0.13
 *
 * which promotes every warning that existed as of v0.13 to an error.
 * Each warning carries the version it was added in, so asking for a
 * version asks for everything noticed up to that point and nothing
 * noticed since -- a project pinned at v0.13 keeps building when
 * v0.14 finds something new, and finds out about it as a warning like
 * everybody else.
 *
 * The default is v0.12, the release these were first written down in,
 * which promotes nothing at all.  That's the whole compatibility
 * story from here on: a new edge case shows up as a warning under the
 * default and as an error for whoever asked for the version it
 * appeared in. */
class strict {
private:
    unsigned _major;
    unsigned _minor;
    unsigned _patch;

public:
    /* The default strictness, which is the oldest one anybody can
     * ask for. */
    strict(void);

    strict(unsigned major, unsigned minor, unsigned patch)
    : _major(major), _minor(minor), _patch(patch)
    {}

public:
    /* Reads one of these the way a person writes it: a leading 'v' is
     * optional, and a component that isn't there is zero, so "v0.13",
     * "0.13" and "v0.13.0" are one version.  Anything that isn't a
     * version at all is a fatal error rather than a warning -- a
     * misspelled STRICT is a line somebody got wrong, and getting it
     * wrong quietly would turn every warning below it back off.
     *
     * Anything older than the default is the default.  There was
     * never a pconfigure that behaved differently, so asking for one
     * is asking for the oldest behaviour there is. */
    static strict parse(const std::string& str, const debug_info::ptr& d);

    /* Spelled the way it's written in a Configfile. */
    std::string to_string(void) const;

    /* TRUE when this strictness is at least the given one, which is
     * what decides whether a warning tagged with that version is an
     * error here. */
    bool at_least(const strict& that) const;

public:
    /* Says that a Configfile did something that's accepted for now
     * and shouldn't be relied on, and either goes on or stops
     * depending on how strict this project asked to be.
     *
     * "since" is the version the warning was added in, which is what
     * a STRICT has to reach for this to become an error.  "what" says
     * what happened, and "instead" says what to write -- both are
     * required, because a warning that only says "no" leaves whoever
     * reads it exactly where they started. */
    void complain(const strict& since,
                  const debug_info::ptr& where,
                  const std::string& what,
                  const std::string& instead) const;
};

/* The versions warnings are tagged with.  These are written down once
 * here rather than spelled out at every warning site, so that the set
 * of versions that mean anything stays small enough to keep in your
 * head. */
namespace strict_since {
    /* Everything found while porting a real project onto pconfigure,
     * which is what prompted all of this. */
    static __inline__ strict v0_13(void) { return strict(0, 13, 0); }
}

#endif
