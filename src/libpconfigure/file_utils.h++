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

#ifndef FILE_UTILS_HXX
#define FILE_UTILS_HXX

#include <functional>
#include <map>
#include <set>
#include <vector>
#include <string>

/* A collection of utilities that deal with files on disk.  This is
 * kind of just a grab bag of stuff that I was hoping would be used a
 * few times throughout the project. */
namespace file_utils {
    /* Returns every line of a file converted into a std::vector. */
    std::vector<std::string> readlines(FILE *f);

    /* Like readlines(), but also returns the line number (1-indexed)
     * for each line that is read from the file.  Useful for parsing
     * files and such.  */
    struct line_and_number {
        std::string line;
        size_t number;
    };
    std::vector<struct line_and_number> readlines_and_numbers(FILE *f);

    /* Like readlines(), but executes the input file with the given
     * argument list.  A command that can't be started or doesn't
     * succeed is handed to "failed", along with how it failed as
     * describe_wait_status() spells it, and "failed" is expected not
     * to return: only the caller knows which Configfile line asked for
     * the command, so only the caller can write the error a reader
     * needs. */
    std::vector<std::string> execlines(
        std::string path,
        std::vector<std::string> args,
        const std::function<void(const std::string&)>& failed
        );

    /* Turns what system() or pclose() returned into the words a person
     * would use for it -- "exited with status 2", "was killed by signal
     * 15 (Terminated)" -- to follow the name of the command.  The raw
     * number is wait()'s encoding, which shifts an exit code left by
     * eight, and nobody reading "status 512" should have to know that
     * it means the script said 2. */
    std::string describe_wait_status(int status);

    /* Tidies a path into the one spelling of it that everything else
     * will use: no "." components, no doubled slashes, and no ".."
     * that something else can absorb.  Two paths that name the same
     * file have to come out of here identical, or the things that
     * match paths against each other will decide they're different
     * files. */
    std::string normalize_path(const std::string& path);

    /* Like normalize_path(), but for a path that names a directory
     * rather than a file: the result ends with a '/', or is empty for
     * the directory pconfigure is running in.
     *
     * This is the spelling that everything which roots a project at a
     * directory uses, so that a subproject asked for as "./sub" and
     * as "sub" is understood to be the same subproject and so that
     * sticking a filename on the end of one always works. */
    std::string normalize_directory(const std::string& path);

    /* TRUE when a path names a directory or names something
     * somewhere underneath it.  Both arguments are spelled the way
     * normalize_path() spells a path: relative to where pconfigure
     * ran, with no trailing '/'.
     *
     * The character after the directory has to be a '/' rather than
     * anything at all, which is the difference between "obj/sub"
     * being inside "obj" and "objects" being inside it.  A directory
     * is inside itself, since every caller of this is asking whether
     * one path may be reasoned about as part of another and a path is
     * part of itself.
     *
     * Both arguments name a directory, and "dir" in particular is a
     * directory some build actually has: every caller asks this of an
     * object directory or of something built out of one, so neither
     * "" nor "." is among the things it has to answer for.  That is
     * worth saying because the answer for those would have to be a
     * special case -- they are spellings of the directory pconfigure
     * ran in, which the test below reads as a name no path starts
     * with -- and a special case nothing reaches is a special case
     * nothing can check.  A caller that wants one is a caller that
     * brings it, and the test that goes with it. */
    bool inside(const std::string& path, const std::string& dir);

    /* The directory a path actually reaches, with every symlink along
     * the way resolved, or "" for a path that doesn't name anything
     * yet.
     *
     * Asked only by the rules about what "make distclean" may reach,
     * and the comments where they ask it say why those are different
     * from every other question about a path: what a line means is
     * settled by its text, but what an "rm -rf" removes is settled by
     * the filesystem. */
    std::string real_directory(const std::string& path);

    /* How to get from one directory to another when both of them are
     * named relative to the same place.  Both arguments and the
     * answer are spelled the way normalize_directory() spells a
     * directory: ending with a '/', or empty for the place they're
     * both named relative to.
     *
     * This is what lets one project's Makefile say where another
     * project is.  pconfigure works out every path from the top of
     * the tree, and a Makefile that make might be run inside has to
     * say the same thing from down there instead. */
    std::string relative_directory(const std::string& from,
                                   const std::string& to);

    /* A directory a Configfile wrote, said from the top of the tree
     * instead.  "base" is the project's directory, spelled the way
     * normalize_directory() spells one.
     *
     * Whoever wrote a Configfile only knew about their own project,
     * so a relative directory in it -- an "-I" or an "-L" -- means one
     * next to that Configfile, while everything that reads it is run
     * from the top.  An absolute directory already means the same
     * thing from everywhere, and an empty one isn't a directory at
     * all, so neither is touched.
     *
     * One function rather than a copy per language, because a
     * subproject's directory is the same directory whichever
     * language asks, and two languages that spelled it differently
     * would find a file in one and miss it in the other. */
    std::string reroot(const std::string& base, const std::string& dir);

    /* Makes a directory and every directory above it, the way
     * "mkdir -p" does, and says whether it worked.  A directory that
     * was already there is a success, since what the caller wanted
     * was for it to exist rather than for it to be new. */
    bool mkdir_p(const std::string& path);

    /* Whether a file already says exactly this, and nothing else.
     *
     * The question write_if_changed asks itself, named so that a
     * caller can ask it without writing anything.  That is for a file
     * whose content is a KEY rather than an output: "was the thing
     * beside this made by what I am about to write down?", where the
     * answer no is a cached answer to throw away rather than a file
     * to bring up to date.  A file that isn't there says nothing, so
     * it does not say this. */
    bool says(const std::string& path, const std::string& contents);

    /* Writes a file, but only when what it should say isn't what it
     * already says.
     *
     * This is for a file that make is going to look at, which makes
     * its mtime the whole point rather than an implementation
     * detail: a file rewritten on every configure would rebuild
     * whatever depends on it on every configure, which is a worse
     * bug than any this fixes.  A file that isn't there yet counts
     * as saying something different. */
    bool write_if_changed(const std::string& path,
                          const std::string& contents);

    /* Gives "path" the mtime "like" has, so that make, which only
     * ever asks whether a prerequisite is newer than its target,
     * finds no reason in "path" to rebuild "like".  Nothing is done
     * when "like" isn't there: a target that doesn't exist is built
     * whatever its prerequisites say.  False, with errno set, only
     * when "like" is there and "path" could not be changed.
     *
     * This is for a record written for the first time beside an
     * output that already exists -- one built before the record was
     * kept at all -- where the record being new says only that it
     * wasn't kept before, not that what it records has changed. */
    bool no_newer_than(const std::string& path, const std::string& like);

    /* write_if_changed(), for a file the build names and nothing in
     * the build makes: one pconfigure writes at configure time for a
     * rule to read or to hang off of, such as the hash of what goes
     * into a link.  Such a file lives in an object directory, and an
     * object directory is a cache people delete -- after which every
     * rule naming one stopped make with "No rule to make target",
     * since the only thing that knew how to write it was pconfigure.
     * So each one is written down along with what it says, and the
     * Makefile make is run on gets a rule that says it again (see
     * configure_outputs()).
     *
     * A file that is only a key -- read by pconfigure on the next run
     * to decide whether something beside it is stale, and named by no
     * rule -- has no need of this, and a missing one already means
     * what it should. */
    bool write_configure_output(const std::string& path,
                                const std::string& contents);

    /* Every file this run wrote through write_configure_output(),
     * and what it wrote there.  Spelled the way the writer spelled
     * it, which is from the top of the tree where pconfigure runs;
     * sorted, so the Makefile that lists them comes out the same on
     * every run that wrote the same files. */
    const std::map<std::string, std::string>& configure_outputs(void);

    /* What git considers ignored inside "srcdir", one entry per
     * top-level ignored file or directory, spelled "srcdir/name" --
     * the same way a caller walking srcdir spells the paths it finds,
     * so a lookup is a set membership test rather than a pattern
     * match.
     *
     * This is for a vendored tree's own scratch: a build system
     * driven from outside has no way to know a foreign tree's output
     * paths ahead of time, but the tree already wrote them down the
     * day it added a .gitignore, and asking git is cheaper than
     * guessing. Empty and silent wherever git has nothing to say --
     * srcdir isn't a checkout, or git isn't installed at all -- so a
     * tree vendored by copying rather than by submodule sees no
     * difference from before this existed. */
    std::set<std::string> git_ignored_paths(const std::string& srcdir);
}

#endif
