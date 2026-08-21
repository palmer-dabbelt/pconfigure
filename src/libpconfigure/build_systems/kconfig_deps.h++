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

#ifndef BUILD_SYSTEMS__KCONFIG_DEPS_HXX
#define BUILD_SYSTEMS__KCONFIG_DEPS_HXX

#include <string>
#include <vector>

/* Guesses at every file a vendored kbuild tree could read.
 *
 * This is a heuristic, and deliberately so.  The build itself is a
 * recursive make, so the vendored build system is the thing that
 * decides what to rebuild -- these are only here so that a "make" in
 * a tree that's already built has a reason not to recurse.  Being
 * generous is free and being wrong is cheap, so nothing here tries to
 * work out what a Kconfig or a Makefile actually means.
 *
 * What it does instead:
 *
 *   - Follows every "source" out of a Kconfig and every "include" out
 *     of a Makefile, paying no attention to the conditionals around
 *     them.  A file that only gets read for some configurations is
 *     still a file this configuration might read tomorrow.
 *
 *   - Treats every word of every Makefile line as a possible path.  A
 *     word ending in '/' is a directory kbuild descends into, so its
 *     Makefile and Kbuild get chased too; a word ending in '.o' is an
 *     object, so the sources it could have been built from get picked
 *     up.
 *
 *   - Turns anything a variable made unreadable into a glob, since
 *     "arch/$(SRCARCH)/Kconfig" names a real file for every value
 *     SRCARCH could take.
 *
 *   - Keeps only the paths that exist right now.  That's what stops a
 *     guess that went wrong from landing in the Makefile as a
 *     prerequisite make has no idea how to build.
 */
namespace kconfig_deps {
    /* The files a chase starts from, spelled the way the Makefile
     * spells them -- so they already have the tree's base on the
     * front, and one that reaches outside the tree is fine.
     *
     * Which files these are is the only thing that changes between
     * one kconfig-derived tree and the next: kbuild starts at a
     * Makefile and a Kconfig, buildroot starts at a Makefile and a
     * Config.in, and everything downstream of that is the same
     * chase. */
    struct roots {
        std::vector<std::string> config;
        std::vector<std::string> build;
    };

    /* The files split by which of the two rules wants them: the
     * configuration is regenerated when a Kconfig changes, and the
     * build is re-entered when anything at all does.
     *
     * Both are sorted, and neither repeats itself. */
    struct dependencies {
        std::vector<std::string> config;
        std::vector<std::string> build;
    };

    /* Chases everything reachable from the given roots.  "base" is
     * the top of the tree, a directory ending with a '/' (or empty,
     * for the directory pconfigure ran in), which is where a path
     * that's relative to the top of the tree gets tried from.  Every
     * path that comes back is spelled relative to the directory
     * pconfigure ran in, which is what the Makefile wants. */
    dependencies chase(const std::string& base, const roots& from);

    /* The paths a defconfig could live at, which is a make target
     * name rather than a filename: "make defconfig" reads
     * "arch/x86/configs/defconfig" or "configs/defconfig" or a file
     * of that name at the top of the tree, depending on the tree.
     * Only the ones that exist come back. */
    std::vector<std::string> defconfig_files(const std::string& base,
                                             const std::string& defconfig);
}

#endif
