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

#ifndef LIBMAKEFILE__PATH_PREFIX_HXX
#define LIBMAKEFILE__PATH_PREFIX_HXX

#include <algorithm>
#include <string>
#include <utility>
#include <vector>

namespace makefile {
    /* Where a project's Makefile sits relative to the directory make
     * was run from, written so that the same Makefile works whether
     * make was run in the project or in a parent that included it.
     *
     * pconfigure always runs at the top of the tree, so every path it
     * works out for a subproject starts with that subproject's
     * directory -- "sub/obj/x.o".  That's right when a parent
     * includes the Makefile and wrong when make runs in "sub", so
     * what gets written out is "$(var)obj/x.o", with the Makefile
     * defaulting "var" to nothing and the parent setting it to
     * "sub/".  One file, both meanings.
     *
     * The same goes for a path that names some other project in the
     * run rather than this one.  A header that "a" compiles against
     * and "b" owns is worked out as "b/src/b.h" from the top, and a
     * Makefile that says that is a Makefile that only works from the
     * top: from inside "a" there is no "b" to find.  So every project
     * gets a variable of its own, and each of them is named through
     * whichever one it belongs to.
     *
     * This is also the reason a project whose directory has an
     * apostrophe in its name does not build, which has been reported
     * enough times to be worth settling here rather than rediscovering
     * again.  The symptom is that pconfigure runs without a word and
     * then the first recipe naming that directory dies with "unexpected
     * EOF while looking for matching `''" -- because the path reaches
     * the shell as a bare word, and an apostrophe is not a character
     * the shell lets a word have.  A "SOURCES += it's.c++" with no
     * subproject involved fails the same way, so it is the character
     * rather than any one command.
     *
     * Quoting the recipes is not the fix, and the obstacle is not this
     * rewrite: separates_words() reads a quote as the end of a word, so
     * a path inside single quotes is still found and still rewritten --
     * which is exactly what buildroot's quoted "BR2_EXTERNAL=$(abspath
     * $(pconfigure_subdir_sub)ext/)" depends on.  The obstacle is one
     * step later.  A subproject's paths reach a recipe as an expansion
     * of the variable above, so quoting the reference quotes nothing
     * that is inside it: '$(pconfigure_subdir_it_s)src/x.c++' expands
     * to 'it's/src/x.c++', the same unbalanced quote arriving later.
     * Nor can the variable hold a shell-escaped path, because the same
     * variable names make prerequisites, and a prerequisite is a word
     * of make rather than a word of shell.
     *
     * The fix is therefore two spellings of every project's directory,
     * one for make and one for the shell, carried through every recipe
     * every language and every build system writes and through
     * rewrite() below, which would have to know which of the two it was
     * substituting into.  That is deliberately not done: it is a great
     * deal of change for a character nobody needs, and half of it buys
     * nothing, since one unquoted recipe fails the build just as
     * completely as all of them.  It is written up for whoever hits it
     * in doc/pconfigure.tex, under "Odd Behavior". */
    class path_prefix {
    private:
        /* The directory, ending in a '/', or empty for a project
         * that nothing includes. */
        const std::string _base;

        /* The make variable that stands in for it. */
        const std::string _variable;

        /* Every project this one might name a path inside, longest
         * directory first so that a project nested inside another is
         * recognized as itself rather than as its parent.  This
         * project is in here too: it's the common case rather than a
         * special one. */
        std::vector<std::pair<std::string, std::string>> _matches;

    private:
        /* Fills in the list above.  "peers" is where the other
         * projects are and what each of their variables is called. */
        void match(const std::vector<
                       std::pair<std::string, std::string>>& peers)
        {
            if (included() == false)
                return;

            _matches.push_back(std::make_pair(_base, reference()));

            for (const auto& peer: peers) {
                /* The project everything is named relative to has no
                 * directory to match, and matching the empty string
                 * would rewrite every path in the file. */
                if (peer.first.size() == 0)
                    continue;
                if (peer.first == _base)
                    continue;

                _matches.push_back(
                    std::make_pair(peer.first, "$(" + peer.second + ")"));
            }

            std::stable_sort(_matches.begin(), _matches.end(),
                             [](const std::pair<std::string, std::string>& a,
                                const std::pair<std::string, std::string>& b)
                             {
                                 return a.first.size() > b.first.size();
                             });
        }

    public:
        path_prefix(void)
        : _base(), _variable(), _matches()
        {}

        path_prefix(const std::string& base,
                    const std::string& variable,
                    const std::vector<std::pair<std::string, std::string>>&
                        peers = {})
        : _base(base), _variable(variable), _matches()
        {
            match(peers);
        }

    public:
        const std::string& base(void) const { return _base; }
        const std::string& variable(void) const { return _variable; }

        /* TRUE when this Makefile can be included by a parent, which
         * is the only time any of the rewriting below happens. */
        bool included(void) const { return _variable.size() > 0; }

        /* How to spell the prefix inside the Makefile. */
        std::string reference(void) const
        {
            if (included() == false)
                return "";
            return "$(" + _variable + ")";
        }

        /* Rewrites the paths in a line of Makefile text so they're
         * relative to the prefix rather than to the top of the tree.
         *
         * A path starts at the beginning of the line, after a space
         * or a shell character that seperates words, or right after a
         * flag like "-I" or "-o" that takes its argument with no
         * space.  It deliberately does not start right after a '/',
         * which is what keeps an install path like
         * "$(DESTDIR)//usr/local/sub/lib" -- or the absolute path of
         * pconfigure's own tools -- from being mangled by a project
         * that happens to be called "sub". */
        std::string rewrite(const std::string& line) const;
    };
}

#endif
