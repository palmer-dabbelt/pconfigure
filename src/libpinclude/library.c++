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

#include <pinclude.h++>
#include <cctype>
#include <fstream>
#include <stack>
#include <iostream>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs,
                   std::vector<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files,
                   pinclude::syntax language,
                   pinclude::directive_callback on_directive,
                   bool refuse_if,
                   bool strict_directives)
{
    std::unordered_set<std::string> define_set;
    for (const auto& define: defines)
        define_set.insert(define);

    return list(filename,
                include_dirs,
                define_set,
                callback,
                skip_missing_files,
                language,
                on_directive,
                refuse_if,
                strict_directives);
}

/* OUTPUT and ELSE are the two halves of a conditional whose
 * enclosing branches are all taken.  DEAD is any conditional inside one
 * that isn't: its own test doesn't matter, and neither does an "#else"
 * in it, because nothing can be live inside a branch that is off. */
enum class state {
    OUTPUT,
    ELSE,
    DEAD,
};

template<typename T> class option {
private:
    bool _valid;
    T _data;

public:
    option(void)
    : _valid(false)
    {}

    option(const T& data)
    : _valid(true),
      _data(data)
    {}

public:
    bool valid(void) const { return _valid; }
    const T& data(void) const { return _data; }
};

/* A heredoc whose body has started arriving and whose end hasn't. */
struct heredoc {
    /* The word that ends it: a heredoc ends at a line that says
     * exactly this and nothing else. */
    std::string delim;

    /* Whether that line is allowed to be indented with tabs, which is
     * what a "<<-" asks for. */
    bool strip_tabs;

    /* Whether it may be indented with any blanks at all, which is
     * what Perl's "<<~" asks for. */
    bool strip_blanks;
};

static void open_heredocs(const std::string& line,
                          std::vector<heredoc>& open,
                          pinclude::syntax language);

static bool closes_heredoc(const std::string& line, const heredoc& open);

static bool ends_perl_script(const std::string& line);

static void check_line(
    const std::string& line,
    const std::string& pp,
    const std::function<void(std::string)> on_match,
    bool bare_directives
);

static bool resolve_pp_function(
    const std::string& f,
    const std::unordered_set<std::string>& defines
);

static bool resolve_pp_function(
    const std::vector<std::string>& f,
    const std::unordered_set<std::string>& defines
);

static bool resolve_pp_function(
    std::vector<std::string>::const_iterator begin,
    std::vector<std::string>::const_iterator end,
    const std::unordered_set<std::string>& defines
);

static bool resolve_pp_defined(
    std::vector<std::string>::const_iterator begin,
    std::vector<std::string>::const_iterator end,
    const std::unordered_set<std::string>& defines
);

template<typename T>
static std::vector<T> cat(const std::vector<T>& a, const std::vector<T>& b)
{
    auto out = std::vector<T>();
    out.insert(out.end(), a.begin(), a.end());
    out.insert(out.end(), b.begin(), b.end());
    return out;
}

static
int list_overwrite_defines(std::string filename,
                           std::vector<std::string> include_dirs_without_cwd,
                           std::unordered_set<std::string>& defines,
                           std::unordered_set<std::string>& reading,
                           std::function<int(std::string)> callback,
                           bool skip_missing_files,
                           pinclude::syntax language,
                           const pinclude::directive_callback& on_directive,
                           bool refuse_if,
                           bool strict_directives);

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs_without_cwd,
                   std::unordered_set<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files,
                   pinclude::syntax language,
                   pinclude::directive_callback on_directive,
                   bool refuse_if,
                   bool strict_directives)
{
    /* The files the scan is in the middle of reading, from this one
     * down to whichever it is reading now.  An include of one of them
     * is a cycle, and following it would go round the cycle until
     * opening one more file failed for want of descriptors or the
     * recursion ran off the end of the stack.  pbashc pastes each
     * file in once, and C stops at "#pragma once" or an include
     * guard, so either way a cycle is something that builds and the
     * scan has to get out of it on its own.
     *
     * This is deliberately not every file the scan has ever been
     * into.  A header with no guard is read again every time it is
     * included, and what it includes can depend on what has been
     * defined since the last time, so a file reached a second time
     * by another route is read again just as it always was.  A
     * guarded header follows nothing on its second read anyway. */
    auto reading = std::unordered_set<std::string>();
    return list_overwrite_defines(
        filename,
        include_dirs_without_cwd,
        defines,
        reading,
        callback,
        skip_missing_files,
        language,
        on_directive,
        refuse_if,
        strict_directives
    );
}

int list_overwrite_defines(std::string filename,
                           std::vector<std::string> include_dirs,
                           std::unordered_set<std::string>& defines,
                           std::unordered_set<std::string>& reading,
                           std::function<int(std::string)> callback,
                           bool skip_missing_files,
                           pinclude::syntax language,
                           const pinclude::directive_callback& on_directive,
                           bool refuse_if,
                           bool strict_directives)
{
    /* Every script is read the strict way, which is the question
     * check_line() asks, and so is a C file whose caller asked for it
     * -- a C test's "#pconfigure" lines, which are spelled the script
     * way even though the rest of the file is read as C. */
    auto bare_directives = language != pinclude::syntax::C
        || strict_directives == true;

    std::ifstream file(filename);
    std::string line;

    std::stack<state> state_stack;
    state_stack.push(state::OUTPUT);

    /* Whether a line is live depends on every conditional around it,
     * not just the innermost one.  Rather than walk the stack on every
     * line, the answer is worked out once as each conditional opens:
     * one opened where lines are live goes by its own test, and one
     * opened anywhere else is dead along with everything inside it. */
    auto push_conditional = [&](bool resolved) {
        if (state_stack.top() != state::OUTPUT)
            state_stack.push(state::DEAD);
        else
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
    };

    static const auto split = [](std::string str, std::string delim) {
        std::vector<size_t> slashes;
        {
            size_t i = 0;
            while (i < str.size() && i != std::string::npos) {
                slashes.push_back(i == 0 ? 0 : i + 1);
                i = str.find_first_of(delim, i + 1);
            }
            slashes.push_back(str.size() + 1);
        }

        std::vector<std::string> out;
        for (size_t i = 0; i < slashes.size() - 1; ++i)
            out.push_back(str.substr(slashes[i], slashes[i+1] - slashes[i] - 1));
        return out;
    };

    static const auto strip_dd = [](std::string in) {
        auto insplit = split(in, "/");
        auto leading_dotdot = [&]() {
            for (size_t i = 0; i < insplit.size(); ++i)
                if (insplit[i] != "..")
                    return i;

            std::cerr << "path is all ..\n";
            abort();
            return (size_t)-1;
        }();

        std::vector<std::string> out;
        for (size_t i = leading_dotdot; i < insplit.size(); ++i) {
            if (insplit[i] == "..")
                out.erase(out.end() - 1);
            else
                out.push_back(insplit[i]);
        }

        std::string ostr = leading_dotdot == 0 ? "" : "..";
        for (size_t i = 1; i < leading_dotdot; ++i)
            ostr = ostr + "/..";
        ostr = ostr + ((ostr.size() == 0) ? "" : "/") + ((out.size() == 0) ? "" : out[0]);
        for (size_t i = 1; i < out.size(); ++i)
            ostr = ostr + "/" + out[i];

        return ostr;
    };

    static const auto get_relative_cwd = [](std::string filename_noncanon) {
        auto filename = strip_dd(filename_noncanon);

        auto last_slash = filename.find_last_of("/");
        if (last_slash == std::string::npos)
            return std::string("");

        return filename.substr(0, last_slash) + "/";
    };

    /* "raw" is the line as it was written, before anything below
     * blanks a comment out of it -- the first line of it, for one
     * continued with a backslash, since pbashc joins nothing and
     * that is the line it quotes.  What is read is the blanked copy,
     * but what is quoted back at whoever wrote the file has to be
     * what they wrote: "#if 0 // off for now" said back to them as
     * "#if 0" and a run of spaces is a line they can't find, and it
     * isn't what pbashc says about the same line, which never strips
     * a C comment out of anything. */
    static const auto next_logical_line = [](std::ifstream& file, std::string& out,
                                             std::string& raw,
                                             int& comment, int& lineno,
                                             pinclude::syntax language) {
        std::string line;
        if (!std::getline(file, line))
            return false;
        out = line;
        raw = line;
        lineno++;

        /* Everything below is how the C preprocessor reads a line:
         * backslash-newline splicing first, then comments.  None of
         * that is how a shell reads one.  The "/" and "*" that end a
         * glob like 'ls "$HOME"/' plus "*" open no comment, and a
         * backslash at the end of a "#" comment or of a line in a
         * quoted heredoc's body doesn't pull the next line up into
         * it.  Read that way, a script's later "#include"s are
         * blanked or swallowed here, pbashc pastes them in anyway,
         * and the file it pasted is one make doesn't know the script
         * depends on, so editing it never rebuilds the script. */
        if (language != pinclude::syntax::C)
            return true;

        /* An empty line has no last character, and asking for one
         * indexes off the front of the string.  Blank lines turn up in
         * every header there is, so this is worth a guard rather than
         * an argument about what the read happens to land on. */
        while (line.size() > 0 && line[line.size() - 1] == '\\') {
            if (!std::getline(file, line))
                return true;

            out = out.substr(0, out.size() - 1) + line;
        }

        /* The comment state has to survive between calls, because a
         * block comment can span lines.  A line comment cannot: it
         * ends at the newline, so it gets a state of its own rather
         * than sharing the block comment's.  1 is the closing slash of
         * a block comment, which is still part of the comment; 2 is
         * inside a block comment; 3 is inside a line comment.  The
         * guards matter as much as the states do: a line comment
         * opened inside a block comment doesn't start anything, and
         * neither does a block comment opened inside a line one. */
        for (size_t i = 0; i < out.size(); ++i) {
            bool was_comment = comment > 0;
            if (comment == 1)
               comment = 0;
            if (comment == 0 && out[i] == '/' && out[i+1] == '/')
              comment = 3;
            if (comment == 0 && out[i] == '/' && out[i+1] == '*')
              comment = 2;
            if (comment == 2 && out[i] == '*' && out[i+1] == '/')
              comment = 1;

            if (was_comment || comment > 0)
              out[i] = ' ';
        }

        /* Whatever a line comment was hiding, it stops hiding it here.
         * Leaving the state set would blank every line that follows,
         * to the end of the file or to whatever stray close of a block
         * comment happened to turn up first. */
        if (comment == 3)
            comment = 0;

        return true;
    };

    /* Labelling an "#else" or an "#endif" with the condition it
     * belongs to is a habit carried over from C, and in a script the
     * label is a shell comment: "#endif # WITH_EXTRAS".  The C
     * spelling never gets this far, since its comments have already
     * been blanked out by the time a line is matched, but a script's
     * comments start with the same '#' a directive does and nothing
     * blanks those.  pbashc only looks at the start of the line for
     * these two and compiles the labelled form happily, so refusing
     * it here would leave a script the compiler accepts as one the
     * project can't be configured around.
     *
     * Only a comment, and only in a script: anything else after the
     * keyword is still a mistake worth stopping for, and in C there
     * is no '#' comment for it to be. */
    const auto only_shell_comment = [&](const std::string& rest) {
        return language != pinclude::syntax::C
            && rest.size() > 0
            && rest[0] == '#';
    };

    /* On the list for as long as this call is reading the file,
     * under the same spelling an include of it is checked against.
     * The scan's own first file goes on it too, so that a helper
     * which includes the script it was included from doesn't make
     * the script a prerequisite of itself. */
    auto reading_as = strip_dd(filename);
    reading.insert(reading_as);

    /* Counted up as a line is read rather than after it has been
     * dealt with, so the count starts one behind what it names: the
     * first line of a file is line 1, and the counter has to have
     * reached it by the time anything is said about that line. */
    int lineno = 0;
    int comment = 0;
    std::vector<heredoc> heredocs;
    auto in_data = false;
    std::string raw;
    while (next_logical_line(file, line, raw, comment, lineno, language)) {
        /* Below a Perl script's "__DATA__" or "__END__" is data the
         * script reads, or nothing at all, and never script -- so an
         * "#include" there is no file the script reads, for the same
         * reason one in a heredoc isn't.  Only to the end of this
         * file, which is how far pperlc takes it too. */
        if (in_data == true)
            continue;

        /* A heredoc's body is text the script writes out rather than
         * script, so an "#include" in one is a line meant for
         * whatever compiles the file being written and not a file
         * this one reads.  Counted as a dependency it makes make
         * rebuild a script whenever some file it only ever mentions
         * changes, and it disagrees with pbashc, which leaves the
         * same line alone.
         *
         * Only for a script: heredocs are a thing scripts have.  A C
         * file's "<<" is a shift, and in C++ it is far more often a
         * stream insertion -- 'std::cout << "x"' reads as a heredoc
         * ending at a line that says "x", which hides every line
         * after it.  The strict directive spelling isn't the question
         * to ask here, since a C test is read with that too. */
        if (language != pinclude::syntax::C) {
            if (heredocs.empty() == false) {
                if (closes_heredoc(line, heredocs.front()) == true)
                    heredocs.erase(heredocs.begin());
                continue;
            }

            open_heredocs(line, heredocs, language);
        }

        /* Whatever the #ifdef state, since pperlc writes this line out
         * either way and perl stops reading there either way. */
        if (language == pinclude::syntax::PERL
            && ends_perl_script(line) == true) {
            in_data = true;
            continue;
        }

        check_line(line, "if", [&](std::string rest) {
            /* pbashc refuses an "#if" in a script rather than working
             * out what it says, and the list of what a script reads
             * has to be found the way pbashc finds it.  Evaluating
             * one here would let "#if 0" leave an include off this
             * list that pbashc either pastes in or stops at, so the
             * answer here is the same refusal, made at configure time
             * rather than at the make that would have failed anyway.
             *
             * The same refusal also covers a comment that starts with
             * the word: "#if you want..." is no expression either,
             * and handed to the reader below it aborts without saying
             * which file it was in. */
            if (refuse_if == true) {
                std::cerr << filename << ":" << lineno << ": '"
                          << raw << "' can't be used in a script\n"
                          << "  only '#ifdef NAME' and '#ifndef NAME'"
                          << " decide what is pasted in, and an '#if'"
                          << " expression is never worked out\n"
                          << "  write '#ifdef NAME' with the name given"
                          << " as a '-D' in COMPILEOPTS, or '# if' with"
                          << " a space if this is a comment\n";
                abort();
            }

            auto resolved = resolve_pp_function(rest, defines);
            push_conditional(resolved);
        }, bare_directives);

        check_line(line, "ifdef", [&](std::string rest) {
            auto resolved = resolve_pp_function("defined(" + rest + ")", defines);
            push_conditional(resolved);
        }, bare_directives);

        check_line(line, "ifndef", [&](std::string rest) {
            auto resolved = resolve_pp_function("!defined(" + rest + ")", defines);
            push_conditional(resolved);
        }, bare_directives);

        check_line(line, "define", [&](std::string rest) {
            auto after = [&]() {
                for (size_t i = 0; i < rest.size(); ++i)
                    if (isspace(rest[i]) || rest[i] == '(')
                        return i;
                return std::string::npos;
            }();

            auto define = (after == std::string::npos)
                ? rest
                : (rest.substr(0, after));
            defines.insert(define);
        }, bare_directives);

        check_line(line, "else", [&](std::string rest) {
            if (only_shell_comment(rest))
                rest = "";

            for (const auto r: rest) {
                if (!isspace(r)) {
                    std::cerr << "There shouldn't be anything after an else\n";
                    std::cerr << "#else\"" << rest << "\"\n";
                    std::cerr << "at " << filename << ":" << lineno << "\n";
                    abort();
                }
            }

            if (state_stack.size() == 0) {
                std::cerr << "else without if\n";
                abort();
            }

            auto ss = state_stack.top();
            state_stack.pop();
            switch (ss) {
            case state::OUTPUT:
                state_stack.push(state::ELSE);
                break;
            case state::ELSE:
                state_stack.push(state::OUTPUT);
                break;
            case state::DEAD:
                state_stack.push(state::DEAD);
                break;
            }
        }, bare_directives);

        check_line(line, "endif", [&](std::string rest) {
            if (only_shell_comment(rest))
                rest = "";

            if (rest != "") {
                std::cerr << "There shouldn't be anything after an endif\n";
                abort();
            }

            if (state_stack.size() == 0) {
                std::cerr << "endif without a cooresponding open\n";
                abort();
            }

            if (state_stack.size() == 0) {
                std::cerr << "endif without if\n";
                abort();
            }
            state_stack.pop();
        }, bare_directives);

        /* Read before the #include below, so that the lines of one
         * file come out in the order they were written in it: an
         * #include is followed all the way down before the line after
         * it is looked at, and a directive further up the same file
         * was written first. */
        check_line(line, "pconfigure", [&](std::string rest) {
            if (state_stack.top() != state::OUTPUT)
                return;

            /* A caller that didn't ask has nowhere to be told, and a
             * file it was reading for the includes alone is not a
             * file it has any opinion about the directives in. */
            if (on_directive == nullptr)
                return;

            on_directive(pinclude::directive{
                filename,
                (size_t)lineno,
                line,
                rest
            });
        }, bare_directives);

        check_line(line, "include", [&](std::string rest) {
            if (state_stack.top() != state::OUTPUT)
                return;

            /* The name ends at its closing quote or '>', which is not
             * the same as at the end of the line.  A C file's comments
             * are blanked out before it gets here, but a script's are
             * not, and pbashc stops at the closing quote and pastes the
             * file in no matter what follows it on the line -- so
             *   #include "helper.bash" # the shared helper
             * is an include of helper.bash, and the scan has to read it
             * as the same file the script is built from.  A name with
             * nothing to close it runs to the end of the line, which is
             * what pbashc does with one as well. */
            auto delimited = [&](char close) {
                auto end = rest.find(close, 1);
                if (end == std::string::npos)
                    return rest.substr(1);
                return rest.substr(1, end - 1);
            };

            auto rest_path = [&]() {
                if (rest[0] == '<')
                    return delimited('>');
                if (rest[0] == '"')
                    return delimited('"');

                std::cerr << "Unable to parse line " << line << "\n";
                std::cerr << "  Unknown include format, expected < or \"" << "\n";
                abort();
            }();

            /* A directory is readable, so access() alone lets one
             * stand in for an include that shares its name.  It is
             * never the file the include means -- pbashc pastes in a
             * directory as nothing at all -- and as a prerequisite it
             * has make watching the wrong thing, so it is passed over
             * like a name that isn't there and the search goes on to
             * the next place the file might be. */
            auto includable = [](const std::string& path) {
                if (access(path.c_str(), R_OK) != 0)
                    return false;

                struct stat st;
                if (stat(path.c_str(), &st) != 0)
                    return false;

                return !S_ISDIR(st.st_mode);
            };

            auto full_path = [&]() {
                auto cwd_relative = get_relative_cwd(filename) + rest_path;
                if (includable(cwd_relative))
                    return option<std::string>(strip_dd(cwd_relative));

                for (const auto& dir: include_dirs) {
                    auto check = dir + "/" + rest_path;
                    if (includable(check))
                        return option<std::string>(strip_dd(check));
                }

                return option<std::string>();
            }();

            if (skip_missing_files == false && full_path.valid() == false) {
                std::cerr << "Unable to open file: " << rest_path << "\n";
                abort();
            }

            /* Compared on the path as it was found, after strip_dd()
             * has taken the ".." out of it, so that "b.bash" from next
             * door and "../src/b.bash" from a sibling directory are
             * the one file they are.  The callback is skipped along
             * with the read: a file still being read has already been
             * named, or is the one the whole scan started from. */
            if (full_path.valid() == true
                && reading.count(full_path.data()) > 0)
                return;

            if (full_path.valid() == true) {
                auto fout = callback(full_path.data());
                if (fout != 0) {
                    std::cerr << "Early out no longer supported in pinclude::list\n";
                    abort();
                }

                auto rout = list_overwrite_defines(
                    full_path.data(),
                    include_dirs,
                    defines,
                    reading,
                    callback,
                    skip_missing_files,
                    language,
                    on_directive,
                    refuse_if,
                    strict_directives
                );
                if (rout != 0) {
                    std::cerr << "Early out no longer supported in pinclude::list\n";
                    abort();
                }
            }
        }, bare_directives);
    }

    reading.erase(reading_as);
    return 0;
}

/* TRUE for a character that ends a word on a shell command line,
 * which is where a heredoc's delimiter ends too. */
static bool ends_shell_word(char c)
{
    if (isspace((unsigned char)c))
        return true;

    switch (c) {
    case ';':
    case '&':
    case '|':
    case '<':
    case '>':
    case '(':
    case ')':
        return true;
    default:
        return false;
    }
}

/* Decodes the backslash escape inside a $'...' that starts at line[i],
 * just past the backslash, the way bash does: \n, \t and the other
 * single letters, up to three octal digits, \x with up to two hex
 * digits, \u and \U as UTF-8, and \c as a control character.  i is
 * left after the escape.  Anything bash doesn't know as an escape is
 * kept, backslash and all, as bash keeps it. */
static std::string decode_ansi_c_escape(const std::string& line, size_t& i)
{
    auto c = line[i++];
    switch (c) {
    case 'a': return "\a";
    case 'b': return "\b";
    case 'e':
    case 'E': return "\033";
    case 'f': return "\f";
    case 'n': return "\n";
    case 'r': return "\r";
    case 't': return "\t";
    case 'v': return "\v";
    case '\\':
    case '\'':
    case '"':
    case '?': return std::string(1, c);
    case 'c':
        if (i >= line.size())
            return "\\c";
        c = line[i++];
        return std::string(1, (c == '?')
                                  ? 0x7f : (toupper((unsigned char)c) & 0x1f));
    }

    int base;
    size_t max_digits;
    switch (c) {
    case 'x': base = 16; max_digits = 2; break;
    case 'u': base = 16; max_digits = 4; break;
    case 'U': base = 16; max_digits = 8; break;
    default:
        if (c < '0' || c > '7')
            return std::string("\\") + c;

        /* An octal escape's first digit is the character right after
         * the backslash; the others name the base and then give
         * digits. */
        base = 8;
        max_digits = 3;
        --i;
        break;
    }

    unsigned long value = 0;
    size_t digits = 0;
    while (digits < max_digits && i < line.size()) {
        auto d = line[i];
        int digit;

        if (base == 8 && d >= '0' && d <= '7')
            digit = d - '0';
        else if (base == 16 && isxdigit((unsigned char)d))
            digit = isdigit((unsigned char)d)
                ? d - '0' : tolower((unsigned char)d) - 'a' + 10;
        else
            break;

        value = value * base + digit;
        ++digits;
        ++i;
    }

    if (digits == 0)
        return std::string("\\") + c;

    if ((c != 'u' && c != 'U') || value < 0x80)
        return std::string(1, (char)value);
    if (value < 0x800)
        return std::string{(char)(0xc0 | (value >> 6)),
                           (char)(0x80 | (value & 0x3f))};
    if (value < 0x10000)
        return std::string{(char)(0xe0 | (value >> 12)),
                           (char)(0x80 | ((value >> 6) & 0x3f)),
                           (char)(0x80 | (value & 0x3f))};
    return std::string{(char)(0xf0 | ((value >> 18) & 0x07)),
                       (char)(0x80 | ((value >> 12) & 0x3f)),
                       (char)(0x80 | ((value >> 6) & 0x3f)),
                       (char)(0x80 | (value & 0x3f))};
}

/* Reads the word a "<<" was given, starting at line[i], and returns it
 * the way the shell compares it against the body's lines: with its
 * quoting taken out.  That quoting can be anywhere in the word and in
 * any of the shell's spellings, so <<'END', <<\END, <<E\ND, <<E"N"D
 * and <<$'END' are all ended by a line saying END; taking only a
 * quote at the front of the word leaves the others waiting for a line
 * no script writes, and the body then swallows the rest of the file.
 * i is left on the character that ended the word.  A quote left open
 * runs to the end of the line, which is as far as anything here
 * reads. */
static std::string read_heredoc_delim(const std::string& line, size_t& i)
{
    std::string out;

    while (i < line.size() && ends_shell_word(line[i]) == false) {
        if (line[i] == '\\' && i + 1 < line.size()) {
            out += line[i + 1];
            i += 2;
            continue;
        }

        if (line[i] == '\'') {
            ++i;
            while (i < line.size() && line[i] != '\'')
                out += line[i++];
            if (i < line.size())
                ++i;
            continue;
        }

        /* A $'...' is single quoting that also reads backslash
         * escapes.  One that comes out as a NUL ends the string as far
         * as bash is concerned, so the rest of the quote adds nothing
         * to the word. */
        if (line[i] == '$' && i + 1 < line.size() && line[i + 1] == '\'') {
            auto ended = false;

            i += 2;
            while (i < line.size() && line[i] != '\'') {
                if (line[i] != '\\' || i + 1 >= line.size()) {
                    if (ended == false)
                        out += line[i];
                    ++i;
                    continue;
                }

                ++i;
                for (auto d: decode_ansi_c_escape(line, i)) {
                    if (d == '\0')
                        ended = true;
                    if (ended == false)
                        out += d;
                }
            }
            if (i < line.size())
                ++i;
            continue;
        }

        /* A $"..." is double quoting that asks for the string to be
         * translated, which is nothing to do with where a body ends;
         * the '$' just goes. */
        if (line[i] == '$' && i + 1 < line.size() && line[i + 1] == '"')
            ++i;

        /* Inside double quotes a backslash only quotes the characters
         * that would mean something there, and is otherwise just a
         * backslash. */
        if (line[i] == '"') {
            ++i;
            while (i < line.size() && line[i] != '"') {
                if (line[i] == '\\' && i + 1 < line.size()
                    && std::string("$`\"\\").find(line[i + 1])
                       != std::string::npos)
                    ++i;
                out += line[i++];
            }
            if (i < line.size())
                ++i;
            continue;
        }

        out += line[i++];
    }

    return out;
}

/* Adds the heredocs a line opens to the ones still waiting for a
 * body, in the order those bodies arrive.
 *
 * What this recognizes is the shape of a redirection and nothing
 * more, which is the same reading pbashc does -- the two have to
 * agree about where a body starts and ends, or the file make is told
 * about is not the file that gets compiled. */
void open_heredocs(const std::string& line, std::vector<heredoc>& open,
                   pinclude::syntax language)
{
    char quoted = '\0';

    /* Where the last delimiter read on this line ended, which no word
     * can at the start of the line. */
    size_t delim_end = 0;

    for (size_t i = 0; i < line.size(); ++i) {
        /* Quoting is followed so that a "<<" written inside a string
         * is left alone, which matters because writing a script out
         * of another script is most of what a heredoc gets used for.
         * Within the line only: a string that runs across several of
         * them is followed by nothing here. */
        if (line[i] == '\\' && quoted != '\'' && i + 1 < line.size()) {
            ++i;
            continue;
        }

        if (quoted != '\0') {
            if (line[i] == quoted)
                quoted = '\0';
            continue;
        }

        if (line[i] == '\'' || line[i] == '"') {
            quoted = line[i];
            continue;
        }

        /* A '#' that starts a word starts a comment, and what a
         * comment has to say about redirection is nothing. */
        if (line[i] == '#'
            && (i == 0 || isspace((unsigned char)line[i - 1])))
            return;

        if (line[i] != '<' || i + 1 >= line.size() || line[i + 1] != '<')
            continue;

        /* A "<<<" is a here-string, which carries its body on the line
         * it's written on and so never waits for one.  All three
         * characters get stepped over rather than one: leaving the
         * second '<' to be looked at again finds a "<<" in what's left
         * of it, and then reads the here-string's text as a
         * delimiter. */
        if (i + 2 < line.size() && line[i + 2] == '<') {
            i += 2;
            continue;
        }

        /* A "<<" with a word character against its left is a shift
         * rather than a redirection: "$((1<<20))" is arithmetic.  The
         * exception is a "<<" written right against the delimiter of
         * the one before it, as in "<<A<<B": there is no arithmetic in
         * a delimiter, and that '<' is what ended it. */
        if (i > 0 && i != delim_end
            && (isalnum((unsigned char)line[i - 1])
                || line[i - 1] == '_'))
            continue;

        i += 2;

        /* A "<<-" says the line that ends the heredoc may be indented
         * with tabs, so that a heredoc can be indented along with the
         * code around it. */
        auto strip_tabs = false;
        if (i < line.size() && line[i] == '-') {
            strip_tabs = true;
            ++i;
        }

        /* Perl's "<<~" is the same idea with any blanks rather than
         * tabs alone.  It is Perl's only: to the shell a "~" is just
         * the first letter of the delimiter, and a shell script that
         * ends its heredoc at "~EOT" has to keep doing so. */
        auto strip_blanks = false;
        if (language == pinclude::syntax::PERL && strip_tabs == false
            && i < line.size() && line[i] == '~') {
            strip_blanks = true;
            ++i;
        }

        while (i < line.size() && isspace((unsigned char)line[i]))
            ++i;

        /* Quoting the delimiter asks for a body the shell expands
         * nothing in, which makes no difference to where that body
         * ends: what ends it is the word with its quoting taken out. */
        auto start = i;
        auto delim = read_heredoc_delim(line, i);

        /* The character that ended the word is looked at again rather
         * than stepped over, since it can be the '<' of another
         * redirection written right against this one, as in
         * "<<'A'<<'B'". */
        auto empty = (i == start);
        delim_end = i;
        --i;

        /* A "<<" with nothing after it isn't a script the shell would
         * run either, so there's nothing here to be right about.  A
         * "<<''" is different: bash takes that as a heredoc an empty
         * line ends, and so does this. */
        if (empty)
            continue;

        open.push_back(heredoc{
            delim,
            strip_tabs,
            strip_blanks
        });
    }
}

bool closes_heredoc(const std::string& line, const heredoc& open)
{
    size_t begin = 0;

    /* A "<<-" strips the leading tabs from every line of the body,
     * and the line that ends it is one of those. */
    if (open.strip_tabs == true)
        while (begin < line.size() && line[begin] == '\t')
            ++begin;

    /* A "<<~" ends at its delimiter however that line is indented. */
    if (open.strip_blanks == true)
        while (begin < line.size()
               && (line[begin] == ' ' || line[begin] == '\t'))
            ++begin;

    auto end = line.size();
    while (end > begin && (line[end - 1] == '\r' || line[end - 1] == '\n'))
        --end;

    return line.compare(begin, end - begin, open.delim) == 0;
}

/* TRUE for the line that ends a Perl script, after which perl reads
 * nothing more of it as code.  The marker is a token rather than a
 * line, so it may be indented, but it is the whole of an identifier:
 * "__END__X" is a name like any other.  The same reading as pperlc's,
 * which is what keeps the two agreeing about where the script ends. */
bool ends_perl_script(const std::string& line)
{
    size_t i = 0;
    while (i < line.size() && (line[i] == ' ' || line[i] == '\t'))
        ++i;

    for (const std::string marker: {"__END__", "__DATA__"}) {
        if (line.compare(i, marker.size(), marker) != 0)
            continue;

        auto end = i + marker.size();
        if (end < line.size()
            && (isalnum((unsigned char)line[end]) || line[end] == '_'))
            continue;

        return true;
    }

    return false;
}

static void check_line(const std::string& line, const std::string& pp, const std::function<void(std::string)> on_match, bool bare_directives)
{
    size_t i = 0;

    /* The first non-whitespace character must be a # */
    while (i < line.size() && isspace(line[i]))
        i++;
    if (line[i] != '#')
        return;

    /* In a shell script a # starts a comment, and the only thing that
     * saves one from being a comment is looking exactly like what
     * pbashc goes looking for: a # in the first column with the
     * keyword written against it.  A comment that wraps onto a line
     * beginning "# include time, rather than..." is not an include and
     * has no business being read as one.  C is more relaxed -- this
     * tree's own sources indent a "# ifdef" inside a conditional -- so
     * the relaxed reading stays the default and the callers that know
     * they are reading a script ask for the other one. */
    if (bare_directives && i != 0)
        return;

    /* After the # there can be any number of spaces, so we just skip them. */
    i++;
    if (bare_directives == false)
        while (i < line.size() && isspace(line[i]))
            i++;

    /* Sometimes this exactly matches the proprocessor declaration. */
    if (line.substr(i) == pp)
        return on_match("");

    /* Check to see if there's trailing space-like things after the
     * declaration. */
    if (line.size() < pp.size())
        return;
    if (line.substr(i, pp.size()) != pp)
        return;

    /* A directive's name ends where an identifier ends, which is not
     * the same as needing whitespace after it.  The C preprocessor
     * tokenizes, so a quote or an angle bracket ends the name just as
     * well as a space does and '#include"a.h"' is a perfectly ordinary
     * include.  What may not follow is another identifier character:
     * without that much, '#ifdef' would match as '#if', and
     * '#include_next' -- a directive in its own right, and not this
     * one -- would match as '#include'. */
    auto after = (unsigned char)line[i + pp.size()];
    if (isalnum(after) || after == '_')
        return;

    /* Here we strip the extra whitespace before after the directive before
     * calling the given function on matches. */
    i += pp.size();
    while (i < line.size() && isspace(line[i]))
        i++;

    /* By the time a line of C gets here its comments have already
     * been blanked out, so what a trailing comment leaves behind is
     * whitespace.  None of the directives has a use for it, and an
     * include whose name is never closed runs to the end of the line,
     * where it would otherwise end up as part of the name. */
    auto end = line.size();
    while (end > i && isspace(line[end - 1]))
        end--;

    return on_match(line.substr(i, end - i));
}

static bool resolve_pp_function(
    const std::string& function,
    const std::unordered_set<std::string>& defines)
{
    static const auto token_terminators = std::vector<std::string>{
        "(", ")", "&&", "||", "!=", "!", "defined", " "
    };
    static const auto terminates = [&](std::string str) -> std::string {
        for (const auto& term: token_terminators) {
            if (str.substr(0, term.size()) == term)
                return term;
        }
        return "";
    };

    static const auto is_all_white = [](std::string str) {
        for (const auto& c: str)
            if (!isspace(c))
                return false;
        return true;
    };

    std::vector<std::string> tokenized;
    {
        size_t token_begin = 0;
        size_t token_end = 0;
        while (token_end < function.size()) {
            auto term = terminates(function.substr(token_end, function.size() - token_end));
            if (term != "") {
                if (token_begin != token_end)
                    tokenized.push_back(function.substr(token_begin, token_end - token_begin));

                if (term != " ")
                    tokenized.push_back(term);

                token_end += term.size();
                token_begin = token_end;
            } else {
                token_end++;
            }
        }

        if (token_begin != token_end)
            tokenized.push_back(function.substr(token_begin, token_end - token_begin));
    }

    /* There's all sorts of complicated options, this ignores most of them. */
    if (tokenized.size() > 5)
        return false;

    std::vector<std::string> stripped;
    for (const auto& token: tokenized) {
        if (!is_all_white(token))
            stripped.push_back(token);
    }

    return resolve_pp_function(stripped, defines);
}

static bool resolve_pp_function(
    const std::vector<std::string>& function,
    const std::unordered_set<std::string>& defines)
{
    return resolve_pp_function(function.begin(), function.end(), defines);
}

static bool resolve_pp_function(
    std::vector<std::string>::const_iterator begin,
    std::vector<std::string>::const_iterator end,
    const std::unordered_set<std::string>& defines)
{
    static const auto pmod = [](std::string token) {
        if (token == "(")
            return 1;
        if (token == ")")
            return -1;
        return 0;
    };

    /* Checks to see if this is a binary op. */
    {
        auto parens = 0;
        auto op_index = [&](){
            for (auto it = begin; it < end; ++it) {
                auto token = *it;
                parens += pmod(token);
                if (parens != 0)
                    continue;

                if (token == "&&" || token == "||" || token == ">" || token == ">=" || token == "<" || token == "<=" || token == "==" || token == "!=")
                    return it;
            }

            return end;
        }();

        if (op_index != end) {
            auto lo = [&](){ return resolve_pp_function(begin, op_index, defines); };
            auto hi = [&](){ return resolve_pp_function(op_index + 1, end, defines); };
            
            if (*op_index == "&&")
                return lo() && hi();
            if (*op_index == "||")
                return lo() || hi();

            /* FIXME: Don't silently drop here. */
            return false;
        }
    }

    /* Checks to see if this is a unary op. */
    {
        if (*begin == "!") {
            return !resolve_pp_function(begin + 1, end, defines);
        }

        if (*begin == "defined") {
            return resolve_pp_defined(begin + 1, end, defines);
        }

        if (*begin == "__GNUC_PREREQ") {
            return false;
        }

        if (*begin == "__GLIBC_USE") {
            return false;
        }
    }

    /* This might just be a single value. */
    {
        if (end - begin == 1) {
            if (*begin == "0")
                return false;

            auto f = defines.find(*begin);
            return f != defines.end();
        }
    }

    /* It's possible the whole thing is wrapped in a ()'s, so just strip that.
     * */
    {
        if (begin[0] == "(" && end[-1] == ")")
            return resolve_pp_function(begin + 1, end - 1, defines);
    }

    /* Something of the shape "NAME ( ... )" that nothing above knew what to
     * do with: a function-like macro, or one of the compiler's feature-test
     * builtins -- __has_attribute, __has_builtin and the rest of that family.
     *
     * Neither can be answered from here.  A builtin asks what the compiler
     * about to build this source can do, and the thing reading the file is not
     * that compiler.  A macro could in principle be expanded, but what is
     * tracked here is which names are defined rather than what they are
     * defined as, so there is nothing to expand it with.
     *
     * So they get the answer __GNUC_PREREQ and __GLIBC_USE above already get,
     * for the same reason and at about the same cost: a branch guessed the
     * wrong way, which almost always holds a macro definition rather than an
     * #include and so holds nothing this is looking for.  __has_include is the
     * one that can really cost something, since that one does guard an
     * #include -- a conditional include of a header that is really there goes
     * unrecorded, and the dependency on it is missed.
     *
     * What this replaces is worse than any of that.  Falling off the end here
     * aborts, so a source reaching libc++ or LLVM's headers -- both of which
     * are full of these -- was a source pconfigure could not read at all, and
     * said so in four lines that named neither the file nor anything to do
     * about it. */
    if ((end - begin) >= 3 && begin[1] == "(" && end[-1] == ")") {
        const auto& name = *begin;
        auto identifier =
            !name.empty()
            && (isalpha((unsigned char)name[0]) || name[0] == '_');

        if (identifier)
            return false;
    }

    std::cerr << "Unable to parse function:\n";
    for (auto it = begin; it < end; ++it) {
        std::cerr << "  f: " << *it << "\n";
    }
    std::cerr << std::endl;
    abort();
    return false;
}

static bool resolve_pp_defined(
    std::vector<std::string>::const_iterator begin,
    std::vector<std::string>::const_iterator end,
    const std::unordered_set<std::string>& defines)
{
    if ((end - begin) == 1) {
        auto f = defines.find(*begin);
        return f != defines.end();
    }

    if ((end - begin) == 3) {
        if (begin[0] != "(" || begin[2] != ")") {
            std::cerr << "Unable to parse defined, expected SYMBOL or (SYMBOL), got\n";
            for (auto it = begin; it < end; ++it)
                std::cerr << "  " << *it << "\n";
            abort();
        }

        auto f = defines.find(begin[1]);
        return f != defines.end();
    }

    std::cerr << "Unable to parse defined, expected SYMBOL or (SYMBOL), got\n";
    for (auto it = begin; it < end; ++it)
        std::cerr << "  " << *it << "\n";
    abort();
    return false;
}
