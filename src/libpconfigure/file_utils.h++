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
     * argument list. */
    std::vector<std::string> execlines(
        std::string path,
        std::vector<std::string> args = std::vector<std::string>()
        );

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

    /* Makes a directory and every directory above it, the way
     * "mkdir -p" does, and says whether it worked.  A directory that
     * was already there is a success, since what the caller wanted
     * was for it to exist rather than for it to be new. */
    bool mkdir_p(const std::string& path);

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
}

#endif
