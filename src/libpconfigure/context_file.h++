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

#ifndef LIBPCONFIGURE__CONTEXT_FILE_HXX
#define LIBPCONFIGURE__CONTEXT_FILE_HXX

#include <functional>
#include <string>
#include <vector>

/* The file pconfigure leaves beside a build for one of its helper
 * tools to read: a line per setting, a key, a space, and whatever is
 * left of the line.
 *
 * There is nothing to it, and that is the point.  It is written at
 * configure time and read during the build, so the two ends of it are
 * two programs that were not necessarily built from the same source
 * -- which is a good reason for the format to have no syntax worth
 * disagreeing about, and a good reason for what little there is to be
 * in one place rather than copied per tool. */
namespace context_file {
    /* Reads a context file, handing each key and value to the caller
     * in the order they were written.  Blank lines are skipped; a key
     * with nothing after it comes back with an empty value.
     *
     * What an unrecognized key means is the caller's business, and
     * every caller so far treats it as fatal: a context file written
     * by a pconfigure that knew about something this tool doesn't
     * means the two disagree about what the build is, and guessing
     * which half is right is how a tree ends up half configured.
     *
     * Returns FALSE when the file could not be read at all. */
    bool read(const std::string& path,
              const std::function<void(const std::string& key,
                                       const std::string& value)>& handle);

    /* Writes a file, making the directory it goes in first.
     * Whatever rule runs the tool makes that directory too, since
     * make wants it made whether the tool is what fills it or not --
     * doing it here as well is what keeps a hand-run from failing
     * with a sentence about a file when the trouble is a directory.
     *
     * Returns FALSE and fills in "error" with something worth
     * printing, since the two ways this goes wrong want different
     * sentences. */
    bool write(const std::string& path,
               const std::string& body,
               std::string& error);

    /* The strings with single spaces between them, which is how a
     * list of prerequisites is spelled. */
    std::string join(const std::vector<std::string>& v);
}

#endif
