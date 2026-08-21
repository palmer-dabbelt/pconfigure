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

#include "kconfig_deps.h++"
#include "../file_utils.h++"
#include <sys/stat.h>
#include <cctype>
#include <cstdio>
#include <glob.h>
#include <map>
#include <set>

namespace {
    /* What a file gets read as, which is the only thing that changes
     * between the two parsers. */
    enum class kind {
        KCONFIG,
        MAKEFILE,
    };

    /* The suffixes an object file could have been built from.  A
     * kbuild tree turns "foo.o" into whichever of these it finds, and
     * since the point here is to notice that the file changed it
     * doesn't matter which one that was. */
    const std::vector<std::string> source_suffixes = {
        ".c", ".cc", ".cpp", ".c++", ".S", ".s", ".rs", ".dts", ".lds",
        ".lds.S", ".y", ".l",
    };

    /* The variables a kbuild tree uses to name a directory, all of
     * which are either the top of the tree or the directory the file
     * being read lives in.  Both of those are already the roots that
     * every path gets tried against, so they become "." here and let
     * the roots do the work. */
    const std::vector<std::string> directory_variables = {
        "$(srctree)", "$(objtree)", "$(abs_srctree)", "$(abs_objtree)",
        "$(srcroot)", "$(src)", "$(obj)", "$(CURDIR)",
        "${srctree}", "${objtree}", "${src}", "${obj}",
    };

    /* Whether a path names a file that's here right now.  Chasing a
     * tree asks about the same path over and over, and a stat that's
     * already been done is the cheapest kind. */
    bool is_file(const std::string& path)
    {
        static auto cache = std::map<std::string, bool>();

        auto found = cache.find(path);
        if (found != cache.end())
            return found->second;

        struct stat buf;
        auto out = stat(path.c_str(), &buf) == 0 && S_ISREG(buf.st_mode);
        cache[path] = out;
        return out;
    }

    /* The directory a path lives in, ending with a '/'. */
    std::string directory_of(const std::string& path)
    {
        auto slash = path.rfind('/');
        if (slash == std::string::npos)
            return "";
        return path.substr(0, slash + 1);
    }

    /* Everything after a '#', which make and Kconfig both treat as a
     * comment, along with the whitespace around what's left. */
    std::string strip_comment(const std::string& line)
    {
        auto out = line.substr(0, line.find('#'));

        while (out.size() > 0 && isspace(out[out.size() - 1]))
            out = out.substr(0, out.size() - 1);

        size_t start = 0;
        while (start < out.size() && isspace(out[start]))
            start++;

        return out.substr(start);
    }

    /* Glues the lines a backslash joined back together, so that a
     * word doesn't get lost just because a list was long enough to
     * wrap. */
    std::vector<std::string> unwrap(const std::vector<std::string>& lines)
    {
        auto out = std::vector<std::string>();
        auto pending = std::string();

        for (const auto& line: lines) {
            auto text = line;
            while (text.size() > 0
                   && (text[text.size() - 1] == '\n'
                       || text[text.size() - 1] == '\r'))
                text = text.substr(0, text.size() - 1);

            if (text.size() > 0 && text[text.size() - 1] == '\\') {
                pending += text.substr(0, text.size() - 1) + " ";
                continue;
            }

            out.push_back(pending + text);
            pending = "";
        }

        if (pending.size() > 0)
            out.push_back(pending);

        return out;
    }

    /* Takes the variables out of a line: the ones that name a
     * directory become ".", and everything else becomes a '*' -- a
     * variable this run can't evaluate still stands for some real
     * path, and a glob is the cheapest way to ask which ones. */
    std::string substitute(const std::string& line)
    {
        auto out = line;

        for (const auto& variable: directory_variables) {
            size_t at = 0;
            while (true) {
                auto found = out.find(variable, at);
                if (found == std::string::npos)
                    break;
                out = out.substr(0, found) + "."
                    + out.substr(found + variable.size());
                at = found + 1;
            }
        }

        auto wild = std::string();
        for (size_t i = 0; i < out.size(); ++i) {
            if (out[i] != '$') {
                wild += out[i];
                continue;
            }

            /* A '$' that doesn't open a variable is a '$' in a shell
             * command, which is nothing this cares about. */
            if (i + 1 >= out.size())
                break;

            if (out[i + 1] != '(' && out[i + 1] != '{')
                continue;

            /* Nested variables ("$(CONFIG_$(X))") close on the last
             * one, which is fine: the whole thing is unknowable
             * either way. */
            auto depth = 0;
            auto end = i;
            for (; end < out.size(); ++end) {
                if (out[end] == '(' || out[end] == '{')
                    depth++;
                else if (out[end] == ')' || out[end] == '}') {
                    if (--depth == 0)
                        break;
                }
            }

            if (end >= out.size())
                break;

            wild += '*';
            i = end;
        }

        return wild;
    }

    /* Splits a line into the words that could be paths.  Everything
     * make uses to seperate one word from the next counts, so that
     * "foo-objs:=a.o" gives up its "a.o" rather than being thrown out
     * whole for having a ':' in it. */
    std::vector<std::string> words_of(const std::string& line)
    {
        auto out = std::vector<std::string>();
        auto word = std::string();

        for (const auto& c: line) {
            switch (c) {
            case ' ': case '\t': case '=': case ':': case ';': case ',':
            case '|': case '&': case '<': case '>': case '"': case '\'':
            case '(': case ')': case '`': case '\\':
                if (word.size() > 0)
                    out.push_back(word);
                word = "";
                break;
            default:
                word += c;
                break;
            }
        }

        if (word.size() > 0)
            out.push_back(word);

        return out;
    }

    /* TRUE for a word that could name a path.  This throws out the
     * things a Makefile line is mostly made of -- flags, pattern
     * rules, automatic variables -- and leaves everything else to the
     * existence check, which is the real filter. */
    bool could_be_path(const std::string& word)
    {
        if (word.size() < 2)
            return false;
        if (word == "..")
            return false;
        if (word[0] == '-')
            return false;

        for (const auto& c: word)
            if (c == '%' || c == '@' || c == '$' || c == '!' || c == '?')
                return false;

        /* Nothing but wildcards and slashes names the whole tree, and
         * the whole tree isn't a dependency. */
        for (const auto& c: word)
            if (c != '*' && c != '/' && c != '.')
                return true;

        return false;
    }

    /* Every existing file a pattern names.  A pattern with no
     * wildcards in it is just a path, which saves the glob. */
    std::vector<std::string> expand(const std::string& pattern)
    {
        if (pattern.find('*') == std::string::npos) {
            if (is_file(pattern) == false)
                return {};
            return {file_utils::normalize_path(pattern)};
        }

        auto out = std::vector<std::string>();
        glob_t found;
        if (glob(pattern.c_str(), 0, NULL, &found) == 0)
            for (size_t i = 0; i < found.gl_pathc; ++i)
                if (is_file(found.gl_pathv[i]) == true)
                    out.push_back(file_utils::normalize_path(found.gl_pathv[i]));
        globfree(&found);

        return out;
    }

    /* Chases a whole tree, one file at a time. */
    class chaser {
    private:
        /* Where the tree is, ending with a '/'. */
        const std::string _base;

        /* The files that have been queued, so that a tree that reads
         * itself in a circle still finishes. */
        std::set<std::string> _seen;

        /* The queue, and how far through it we've gotten.  This isn't
         * a recursion because a deep tree would be a deep stack, and
         * the depth of a vendored tree isn't ours to bound. */
        std::vector<std::pair<std::string, kind>> _queue;
        size_t _at;

        /* What came out. */
        std::set<std::string> _config;
        std::set<std::string> _build;

    public:
        chaser(const std::string& base)
        : _base(base), _seen(), _queue(), _at(0), _config(), _build()
        {}

    public:
        kconfig_deps::dependencies run(void)
        {
            /* A kbuild tree is rooted at a Makefile and a Kconfig,
             * and some trees use a Kbuild alongside the Makefile. */
            queue(_base + "Makefile", kind::MAKEFILE);
            queue(_base + "Kbuild", kind::MAKEFILE);
            queue(_base + "Kconfig", kind::KCONFIG);

            while (_at < _queue.size()) {
                auto entry = _queue[_at++];
                read(entry.first, entry.second);
            }

            auto out = kconfig_deps::dependencies();
            for (const auto& path: _config)
                out.config.push_back(path);
            for (const auto& path: _build)
                out.build.push_back(path);
            return out;
        }

    private:
        /* Queues everything a pattern names, if it hasn't been
         * queued already. */
        void queue(const std::string& pattern, kind as)
        {
            for (const auto& path: expand(pattern)) {
                if (_seen.insert(path).second == false)
                    continue;
                _queue.push_back(std::make_pair(path, as));
            }
        }

        /* Records a file that gets read but never chased, which is
         * everything that isn't itself part of the build
         * description. */
        void record(const std::string& pattern)
        {
            for (const auto& path: expand(pattern))
                _build.insert(path);
        }

        void read(const std::string& path, kind as)
        {
            if (as == kind::KCONFIG)
                _config.insert(path);
            else
                _build.insert(path);

            auto file = fopen(path.c_str(), "r");
            if (file == NULL)
                return;
            auto lines = unwrap(file_utils::readlines(file));
            fclose(file);

            auto here = directory_of(path);
            for (const auto& line: lines) {
                if (as == kind::KCONFIG)
                    read_kconfig_line(line, here);
                else
                    read_makefile_line(line, here);
            }
        }

        /* A Kconfig only reaches other Kconfigs, and only ever says
         * so with a "source".  The four spellings differ in whether
         * the path is relative to the top of the tree and in whether
         * a missing file is an error, and neither matters here: both
         * roots get tried, and a file that isn't there falls out at
         * the existence check anyway. */
        void read_kconfig_line(const std::string& line, const std::string& here)
        {
            auto words = words_of(substitute(strip_comment(line)));
            if (words.size() < 2)
                return;

            const auto& directive = words[0];
            if (directive != "source" && directive != "rsource"
                && directive != "osource" && directive != "orsource")
                return;

            for (size_t i = 1; i < words.size(); ++i) {
                if (could_be_path(words[i]) == false)
                    continue;
                queue(_base + words[i], kind::KCONFIG);
                queue(here + words[i], kind::KCONFIG);
            }
        }

        void read_makefile_line(const std::string& line,
                                const std::string& here)
        {
            auto words = words_of(substitute(strip_comment(line)));
            if (words.size() == 0)
                return;

            /* An include names a Makefile no matter what it looks
             * like, so it gets chased rather than just recorded. */
            auto including = words[0] == "include" || words[0] == "-include"
                          || words[0] == "sinclude";

            for (size_t i = 0; i < words.size(); ++i) {
                const auto& word = words[i];
                if (could_be_path(word) == false)
                    continue;

                if (including == true && i > 0) {
                    queue(_base + word, kind::MAKEFILE);
                    queue(here + word, kind::MAKEFILE);
                    continue;
                }

                /* "obj-y += drivers/" is kbuild descending into a
                 * directory, which is where the rest of the build
                 * description lives. */
                if (word[word.size() - 1] == '/') {
                    for (const auto& root: {_base, here}) {
                        queue(root + word + "Makefile", kind::MAKEFILE);
                        queue(root + word + "Kbuild", kind::MAKEFILE);
                        queue(root + word + "Kconfig", kind::KCONFIG);
                    }
                    continue;
                }

                /* An object names a source file that doesn't exist
                 * under that name, so the suffix has to be guessed
                 * back.  Whichever guesses land on a real file are
                 * the ones this build could have read. */
                if (word.size() > 2
                    && word.compare(word.size() - 2, 2, ".o") == 0) {
                    auto stem = word.substr(0, word.size() - 2);
                    for (const auto& root: {_base, here})
                        for (const auto& suffix: source_suffixes)
                            record(root + stem + suffix);
                    continue;
                }

                /* Anything else is only a dependency if it happens to
                 * name a file, which most words don't. */
                for (const auto& root: {_base, here})
                    record(root + word);
            }
        }
    };
}

kconfig_deps::dependencies kconfig_deps::chase(const std::string& base)
{
    return chaser(base).run();
}

std::vector<std::string> kconfig_deps::defconfig_files(const std::string& base,
                                                       const std::string& defconfig)
{
    /* "make defconfig" doesn't say which file it reads, and where a
     * tree keeps its defconfigs is up to the tree.  These are the
     * places they turn up, and a defconfig that isn't a file at all
     * -- an alias some Makefile builds up -- just doesn't match. */
    auto patterns = std::vector<std::string>{
        base + "arch/*/configs/" + defconfig,
        base + "arch/*/*/configs/" + defconfig,
        base + "configs/" + defconfig,
        base + defconfig,
    };

    auto out = std::set<std::string>();
    for (const auto& pattern: patterns)
        for (const auto& path: expand(pattern))
            out.insert(path);

    return std::vector<std::string>(out.begin(), out.end());
}
