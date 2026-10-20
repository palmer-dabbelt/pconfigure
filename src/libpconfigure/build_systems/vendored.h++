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

#ifndef BUILD_SYSTEMS__VENDORED_HXX
#define BUILD_SYSTEMS__VENDORED_HXX

#include <set>
#include <string>
#include <vector>

/* The pieces of a vendored build system's rules that don't depend on
 * which build system it is.
 *
 * These started out inside cmake.c++, which was the first build
 * system to configure a tree into a directory it then threw away and
 * made again.  They moved here when a second one did the same thing,
 * rather than being copied: each of them is the answer to a question
 * that was worked out the hard way -- a path rewritten that shouldn't
 * have been, a build directory walked as though it were source -- and
 * two copies of an answer is how one of them stops being right. */
namespace vendored {
    /* One argument of text that is being written down rather than
     * run, quoted so that nothing between here and the file gets to
     * change a character of it: not make's variables, not the
     * shell's idea of a space, and not the path rewriting that lets
     * a subproject's Makefile be included by its parent's.  See the
     * definition for why the last of those needs more than quotes. */
    std::string recorded(const std::string& in);

    /* A signature taken apart into the lines it was built out of.  A
     * recipe is a line of shell, so text with newlines in it has to
     * reach the file as one argument per line rather than as
     * itself. */
    std::vector<std::string> signature_lines(const std::string& in);

    /* Every directory under a vendored tree, written as one glob
     * apiece for make to expand, into "out".
     *
     * "dir" is where to start, ending in a '/'.  "skip" is a
     * directory not to walk, which is the output directory of the
     * build system doing the asking: it is only under the tree if
     * somebody put it there, and it is never source.  "marker" is the
     * name of the file a build directory of this kind has in it --
     * "CMakeCache.txt" for cmake -- and a directory below the top
     * that has one is output rather than source, so it is not walked
     * either.  "ignored" is what the tree's own .gitignore says isn't
     * source, as file_utils::git_ignored_paths() reads it.
     *
     * "root" is TRUE for the first call and FALSE for every call it
     * makes, which is what exempts the directory the walk was pointed
     * at from the marker check: a tree somebody configured in place is
     * still a tree they asked to have built.
     *
     * A directory with a symlink to nothing in it is written out a
     * file at a time instead, leaving the link out: a glob would list
     * it, and make would then have a prerequisite it can't find. */
    void chase(const std::string& dir,
               const std::string& skip,
               const std::string& marker,
               bool root,
               const std::set<std::string>& ignored,
               std::vector<std::string>& out);

    /* The globs chase() wrote, as the one prerequisite a build
     * waits on.  See the definition for why that's two
     * "$(wildcard)"s rather than one. */
    std::string globbed(const std::vector<std::string>& globs);
}

#endif
