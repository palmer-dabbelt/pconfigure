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

#include "vendored.h++"
#include "../string_utils.h++"
#include <sys/stat.h>
#include <dirent.h>

/* One argument of text that is being written down rather than run,
 * quoted so that nothing between here and the file gets to change
 * a character of it.
 *
 * string_utils::quoted() keeps the shell out of it and
 * string_utils::unexpanded() keeps make's variables out of it,
 * which between them are string_utils::echoed() and used to be
 * the whole list.
 * They aren't, and that is why this is not simply a call to
 * echoed().  Every recipe line written here goes through
 * path_prefix::rewrite() on its way into the Makefile, which finds
 * anything that looks like a path into one of the projects of this
 * run and puts the variable that stands for that project's
 * directory in front of what's left.  That is exactly right for
 * the paths in a command -- it is the whole of what lets a
 * subproject's Makefile be included by its parent's and still name
 * the same files -- and exactly wrong here, where the text is an
 * argument to a printf rather than a path to anything.  A
 * '--env FOO=child/x' written in the subproject "child" would
 * otherwise be recorded as "child/x" by a make run at the top and
 * as "x" by a make run in the subproject, so one configuration
 * would write down two different things and the rule that exists
 * to notice an option moving would notice make moving instead.
 *
 * What stops it is that every directory rewrite() can match ends
 * in a '/', so a '/' that no directory name runs up to is a '/' it
 * has nothing to match on.  Closing the quotes around each piece
 * between the slashes buys that for nothing: the shell glues
 * "'child'/'x'" back into the single word "child/x", and what the
 * Makefile holds has no "child/" anywhere in it for the rewriting
 * to find. */
std::string vendored::recorded(const std::string& in)
{
    auto text = string_utils::unexpanded(in);
    auto out = std::string();

    size_t start = 0;
    while (true) {
        auto slash = text.find('/', start);
        if (slash == std::string::npos)
            return out + string_utils::quoted(text.substr(start));

        out += string_utils::quoted(text.substr(start, slash - start))
             + "/";
        start = slash + 1;
    }
}

/* A signature taken apart into the lines it was built out of.  A
 * recipe is a line of shell, so text with newlines in it has to
 * reach the file as one argument per line rather than as itself. */
std::vector<std::string> vendored::signature_lines(const std::string& in)
{
    auto out = std::vector<std::string>();

    size_t start = 0;
    while (start < in.size()) {
        auto end = in.find('\n', start);
        if (end == std::string::npos)
            end = in.size();
        out.push_back(in.substr(start, end - start));
        start = end + 1;
    }

    return out;
}

/* Every directory under a vendored tree, written as one glob
 * apiece for make to expand.
 *
 * This is a guess and deliberately a generous one.  The build
 * itself is somebody else's build system, which is the thing that
 * decides what to recompile -- all this is for is giving a "make"
 * in a tree that's already built a reason not to recurse at all.
 * Nothing here tries to work out what a CMakeLists.txt or a
 * meson.build means: the only program that knows which files a tree
 * like that reads is the one that reads them, and it only knows
 * after it has run.
 *
 * A directory rather than a list of files, because a tree like that
 * names its sources inside its own build files and reading them
 * back out is the one thing we've just said we won't do.  It also
 * keeps this cheap where it matters: LLVM is a hundred and forty
 * thousand files in four thousand directories, and one word per
 * directory is a prerequisite list make can hold an opinion about
 * while one word per file is a megabyte of Makefile.  What it
 * costs is precision -- a directory's own timestamp moves when
 * something is added to it or taken out of it, and the files
 * inside it are named by the glob -- which for a vendored tree
 * that nothing but git ever writes to is precision nobody misses.
 *
 * The "$(wildcard)" that wraps the result is the other half of
 * the answer, and it's the half that matters on a submodule bump:
 * these paths were true when pconfigure looked, a bump deletes
 * some of them, and a prerequisite that is named outright and has
 * gone away stops make building anything at all -- not just this
 * subproject -- with an error that never mentions the way out.
 *
 * None of these is quoted, and there is nowhere to put the
 * quotes: what they become is a prerequisite list rather than a
 * command.  make splits that on spaces, "$(wildcard)" splits its
 * own argument on spaces again before it globs anything, and no
 * shell ever reads the line -- so a quote written here would be a
 * character in a file name rather than a quote.  A vendored
 * directory whose name has a space in it therefore arrives as two
 * words that name nothing the tree has and drops out of the list,
 * and what that costs is a re-entry into the tree that should
 * have happened: the guess got shorter, which is the one way this
 * guess is allowed to be wrong.  It is not the way the paths in
 * the recipes below are allowed to be wrong, which is why the
 * difference is written down here rather than left looking like
 * an oversight. */
void vendored::chase(const std::string& dir,
                     const std::string& skip,
                     const std::string& marker,
                     bool root,
                     const std::set<std::string>& ignored,
                     std::vector<std::string>& out)
{
    /* A tree named as the directory pconfigure itself ran in has
     * no walk that makes sense: everything this project builds is
     * under there too, including the output directory this walk
     * is about to be a prerequisite of. */
    if (dir.size() == 0)
        return;

    auto handle = opendir(dir.c_str());
    if (handle == NULL)
        return;

    auto subdirs = std::vector<std::string>();
    auto configured = false;

    while (true) {
        auto entry = readdir(handle);
        if (entry == NULL)
            break;

        auto name = std::string(entry->d_name);

        /* "." and ".." would walk this tree forever, and the rest
         * of what starts with a dot is version control and
         * editor scratch: a build that re-entered the tree every
         * time git wrote an index would re-enter it constantly.
         * $(wildcard) doesn't match them either, so leaving them
         * out here says the same thing the globs say. */
        if (name.size() == 0 || name[0] == '.')
            continue;

        auto path = dir + name;

        /* A directory reached through a symlink is not followed.
         * A tree with a link to one of its own parents in it
         * would otherwise not be walked so much as fallen into. */
        struct stat info;
        if (lstat(path.c_str(), &info) != 0)
            continue;

        if (S_ISDIR(info.st_mode) == true) {
            /* A directory the tree's own .gitignore says is
             * output rather than source, the same reasoning as
             * the marker check below applied one step
             * earlier: nothing recurses into it, so nothing in it
             * becomes a glob a rewrite of it could make newer
             * than the build.  llvm/utils/lit's own
             * "__pycache__", left behind by running lit itself,
             * is exactly this -- a directory the source tree
             * never had until the tests were run once, and would
             * otherwise look like a source change on every build
             * after. */
            if (ignored.count(path) > 0)
                continue;

            subdirs.push_back(path + "/");
            continue;
        }

        if (name == marker)
            configured = true;
    }

    closedir(handle);

    /* A directory with the marker in it is a build directory,
     * which is output rather than source: walking it would make
     * the tree's own product a prerequisite of building the tree,
     * and make would then have a reason to rebuild after every
     * build, forever.  The tree this was pointed at is exempt,
     * since somebody who configured it in place is still asking
     * for it to be built and the alternative is walking nothing
     * at all. */
    if (configured == true && root == false)
        return;

    /* And the same again for the directory this build system is
     * about to write into, which is only under the tree if
     * somebody put the object directory there. */
    if (dir == skip)
        return;

    out.push_back(dir + "*");

    for (const auto& subdir: subdirs)
        chase(subdir, skip, marker, false, ignored, out);
}
