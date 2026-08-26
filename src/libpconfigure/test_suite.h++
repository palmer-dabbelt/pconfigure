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

#ifndef TEST_SUITE_HXX
#define TEST_SUITE_HXX

#include <memory>
#include <string>
#include <vector>
#include "command.h++"

/* One of the sets a project's tests are divided into, as a
 * TEST_SUITES line declared it.
 *
 * A project that has tests it can't always run -- the ones that want
 * a network, or a card, or an hour -- has no way to say so with one
 * set of tests: whatever "make check" means has to mean the same
 * thing everywhere it gets run.  A suite is a name for a subset of
 * the tests, and a project can have as many of them as it has
 * answers to "which tests can this machine run".
 *
 * Nothing here says which tests are in the suite.  A suite is named
 * from both ends -- the tests that join it say so themselves -- so
 * all that a declaration carries is the name and whatever the lines
 * underneath it added. */
class test_suite {
public:
    typedef std::shared_ptr<test_suite> ptr;

private:
    const std::string _name;

    /* The TEST_SUITES line that declared it, which is what a
     * complaint about the suite points at. */
    const command::ptr _cmd;

    /* The INCLUDE_TEST_SUITES lines underneath it, kept as the
     * commands they were rather than as the names they hold: a
     * complaint about one of them points at the line that wrote it,
     * and that line is a long way from the suite by the time anything
     * is in a position to notice. */
    std::vector<command::ptr> _includes;

public:
    test_suite(const std::string& name, const command::ptr& cmd)
    : _name(name),
      _cmd(cmd),
      _includes()
    {}

public:
    const std::string& name(void) const { return _name; }
    const command::ptr& cmd(void) const { return _cmd; }
    const std::vector<command::ptr>& includes(void) const { return _includes; }

    void add_include(const command::ptr& cmd) { _includes.push_back(cmd); }
};

#endif
