/*
 * Copyright (C) 2016 Palmer Dabbelt
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

#ifndef PINCLUDE_HXX
#define PINCLUDE_HXX

#include <functional>
#include <string>
#include <vector>
#include <unordered_set>

namespace pinclude {
    /* A line a file wrote for whatever is building it rather than for
     * whatever ends up running it: a "#pconfigure" with a command
     * after it.  What the command means is none of pinclude's
     * business -- all this does is find the lines and say where they
     * were, which is a question only the thing that followed the
     * #includes can answer. */
    struct directive {
        /* The file the line was written in and the line it was
         * written on.  A directive can come out of a file that was
         * included rather than out of the one that was listed, so
         * neither of these is something the caller already knows. */
        std::string filename;
        size_t line_number;

        /* The line as it was read, and the part of it after the
         * "#pconfigure".  The first is for pointing at, the second is
         * the thing being said. */
        std::string line;
        std::string data;
    };

    /* What to do with each of those, in the order they were read --
     * which is the order they would be read in with the #includes
     * expanded, since that is how they are found. */
    typedef std::function<void(const directive&)> directive_callback;

    /* What a file is written in, which decides what counts as a
     * directive and which lines can't be one whatever they look
     * like.
     *
     * C is the relaxed reading, where a directive may be indented
     * and may have space between its '#' and its name -- this tree's
     * own sources indent a "# ifdef" inside a conditional.  A script
     * gets the stricter one: a '#' in the first column with the
     * keyword written against it, and nothing else, since anywhere
     * else a '#' starts a comment.  A script also carries text that
     * isn't script at all, a heredoc's body, and what that looks
     * like is where the two scripting languages part: Perl writes
     * an indented heredoc as "<<~", which to the shell is a heredoc
     * ending at "~", and Perl ends the script itself at a
     * "__DATA__" or "__END__" line. */
    enum class syntax {
        C,
        SHELL,
        PERL,
    };

    /* Looks through the given file for #include lines, calling the given
     * callback for any included file that exists inside one of the given
     * include_dirs.  This handles some simple CPP #define-related things, the
     * list of default definitions is given in defined.  Any non-zero return
     * value from the callback stops parsing and returns that value.
     *
     * language says which of the readings above to use, and is C
     * unless the caller knows better.
     *
     * on_directive is handed every "#pconfigure" line found on the way
     * through, and defaults to nothing at all for the callers that
     * only ever wanted the file list. */
    int list(std::string filename,
             std::vector<std::string> include_dirs,
             std::vector<std::string> defined,
             std::function<int(std::string)> callback,
             bool skip_missing_files,
             syntax language = syntax::C,
             directive_callback on_directive = {});

    int list(std::string filename,
             std::vector<std::string> include_dirs,
             std::unordered_set<std::string> defined,
             std::function<int(std::string)> callback,
             bool skip_missing_files,
             syntax language = syntax::C,
             directive_callback on_directive = {});

    static inline
    int list(std::string filename,
             std::function<int(std::string)> callback,
             bool skip_missing_files,
             syntax language = syntax::C,
             directive_callback on_directive = {})
    {
        return list(filename,
                    std::vector<std::string>{},
                    std::vector<std::string>{},
                    callback,
                    skip_missing_files,
                    language,
                    on_directive
                );
    }
}

#endif
