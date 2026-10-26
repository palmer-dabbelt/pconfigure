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
                   pinclude::search_path include_dirs,
                   std::vector<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files,
                   pinclude::syntax language,
                   pinclude::directive_callback on_directive,
                   bool refuse_if,
                   bool strict_directives,
                   std::unordered_set<std::string> promised,
                   pinclude::missed_callback on_missed)
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
                strict_directives,
                promised,
                on_missed);
}

/* OUTPUT, ELSE and DONE are the states of a conditional whose
 * enclosing branches are all taken.  OUTPUT is the branch being read
 * now; ELSE is one that is off while no branch of the chain has been
 * taken yet, so the next "#elif" or "#else" may still be; DONE is
 * every branch after the one that was taken, which stays off whatever
 * an "#elif" says.  DEAD is any conditional inside a branch that is
 * off: its own test doesn't matter, and neither does an "#elif" or an
 * "#else" in it, because nothing can be live inside a branch that is
 * off. */
enum class state {
    OUTPUT,
    ELSE,
    DONE,
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
                           pinclude::search_path include_dirs_without_cwd,
                           std::unordered_set<std::string>& defines,
                           std::unordered_set<std::string>& reading,
                           std::function<int(std::string)> callback,
                           bool skip_missing_files,
                           pinclude::syntax language,
                           const pinclude::directive_callback& on_directive,
                           bool refuse_if,
                           bool strict_directives,
                           const std::unordered_set<std::string>& promised,
                           const pinclude::missed_callback& on_missed);

int pinclude::list(std::string filename,
                   pinclude::search_path include_dirs_without_cwd,
                   std::unordered_set<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files,
                   pinclude::syntax language,
                   pinclude::directive_callback on_directive,
                   bool refuse_if,
                   bool strict_directives,
                   std::unordered_set<std::string> promised,
                   pinclude::missed_callback on_missed)
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
        strict_directives,
        promised,
        on_missed
    );
}

int pinclude::list_defining(std::string filename,
                            pinclude::search_path include_dirs,
                            std::unordered_set<std::string>& defines,
                            std::function<int(std::string)> callback,
                            bool skip_missing_files,
                            std::unordered_set<std::string> promised,
                            pinclude::missed_callback on_missed)
{
    /* A cycle is a cycle within this one file's includes, the same as
     * for list(): the file read after this one starts again with
     * nothing being read, and only the defines carry over. */
    auto reading = std::unordered_set<std::string>();
    return list_overwrite_defines(
        filename,
        include_dirs,
        defines,
        reading,
        callback,
        skip_missing_files,
        pinclude::syntax::C,
        pinclude::directive_callback(),
        false,
        false,
        promised,
        on_missed
    );
}

int list_overwrite_defines(std::string filename,
                           pinclude::search_path include_dirs,
                           std::unordered_set<std::string>& defines,
                           std::unordered_set<std::string>& reading,
                           std::function<int(std::string)> callback,
                           bool skip_missing_files,
                           pinclude::syntax language,
                           const pinclude::directive_callback& on_directive,
                           bool refuse_if,
                           bool strict_directives,
                           const std::unordered_set<std::string>& promised,
                           const pinclude::missed_callback& on_missed)
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

    /* The one spelling a path is listed under, however the include
     * and the directory it was found through spelled it.  A header's
     * name is what the source behind it is found from and what the
     * scan remembers it by, so two spellings of one file are two
     * headers: "./extra.h" beside "extra.h", or "-Isrc/lib/" glued
     * onto a name as "src/lib//extra.h", had the source behind it
     * compiled and linked once per spelling, and "-I./src/lib" gave
     * a source under "./src/" that was never taken for one of the
     * project's at all.  So "." and empty components go, and each
     * ".." takes off the directory before it.
     *
     * A ".." with nothing left before it to take off climbs out of
     * wherever the path started, and stays: "../extra.h" from the
     * top of the tree, or "src/../../shared/shared.h" out of the
     * project altogether, is a file the compiler finds there, and
     * the path to it has to keep saying so.  Above the root of an
     * absolute path there is nowhere further to go, so a ".." there
     * is the root again, as it is to the kernel.
     *
     * An empty name has nothing to take out of it.  pinclude run
     * with no file at all asks for one: there is nothing to read,
     * so the list is empty, and the spelling the scan keeps it under
     * while reading it is empty too. */
    static const auto strip_dd = [](std::string in) {
        if (in.empty())
            return in;

        bool absolute = in[0] == '/';

        std::vector<std::string> out;
        size_t start = 0;
        while (start <= in.size()) {
            auto end = in.find('/', start);
            if (end == std::string::npos)
                end = in.size();
            auto component = in.substr(start, end - start);
            start = end + 1;

            if (component.empty() || component == ".")
                continue;

            if (component == "..") {
                if (!out.empty() && out.back() != "..")
                    out.pop_back();
                else if (!absolute)
                    out.push_back(component);
                continue;
            }

            out.push_back(component);
        }

        std::string ostr = absolute ? "/" : "";
        for (size_t i = 0; i < out.size(); ++i)
            ostr = ostr + ((i == 0) ? "" : "/") + out[i];

        /* Every component cancelled out: the path is the directory it
         * started from, which still needs a name to be a path. */
        if (ostr.empty())
            return std::string(".");
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

        /* Only a block comment can still be open when the line ends,
         * so it is the only state kept between calls: "comment" is 1
         * while one is open and 0 otherwise.  Everything else below
         * ends with the line it is on.
         *
         * A slash and a star only open a comment when they are C.
         * Inside a string literal, a character literal or an
         * #include's header name they are not: a glob of log files
         * in a string has them side by side and opens nothing, '"' is
         * a character rather than the start of a string, and in
         * #include "lib//extra.h" the two slashes are part of a file
         * name the compiler opens as lib/extra.h.  Blanked as a
         * comment, any of those hides what comes after it -- every
         * later #include, for a block comment that is never closed --
         * so the literals are walked as the compiler walks them,
         * escapes and all.  A literal still open at the end of the
         * line is a program the compiler refuses, and this doesn't
         * try to be cleverer about one than ending it there. */
        enum class in { CODE, LINE_COMMENT, LITERAL, HEADER };
        auto at = in::CODE;
        auto close = '\0';
        auto peek = [&](size_t i) {
            return i + 1 < out.size() ? out[i + 1] : '\0';
        };

        /* A header name is only where an #include puts one, which
         * is directly after the word.  Anywhere else a '<' is a
         * comparison or a template's bracket, and taken for a header
         * name it would hide a real comment up to the next '>'; a '"'
         * anywhere else is a string literal, which is read the same
         * way but for its escapes. */
        auto opens_header_name = [&](size_t i) {
            size_t j = 0;
            while (j < i && isspace((unsigned char)out[j]))
                j++;
            if (j >= i || out[j] != '#')
                return false;
            j++;
            while (j < i && isspace((unsigned char)out[j]))
                j++;
            if (out.compare(j, 7, "include") != 0)
                return false;
            j += 7;
            while (j < i && isspace((unsigned char)out[j]))
                j++;
            return j == i;
        };

        /* Since C++14 a quote inside a number separates its digits --
         * 1'000'000 -- and opens nothing.  The number is the run of
         * pp-number characters the quote is in the middle of, and it
         * is a number rather than an L'x' or u8'x' prefix when that
         * run starts with a digit. */
        auto separates_digits = [&](size_t i) {
            size_t j = i;
            while (j > 0 && (isalnum((unsigned char)out[j - 1])
                             || out[j - 1] == '_'
                             || out[j - 1] == '.'
                             || out[j - 1] == '\''))
                j--;
            return j < i && isdigit((unsigned char)out[j]);
        };

        for (size_t i = 0; i < out.size(); ++i) {
            if (comment == 1) {
                if (out[i] == '*' && peek(i) == '/') {
                    out[i] = ' ';
                    out[++i] = ' ';
                    comment = 0;
                    continue;
                }
                out[i] = ' ';
                continue;
            }

            switch (at) {
            case in::LINE_COMMENT:
                out[i] = ' ';
                continue;

            case in::LITERAL:
            case in::HEADER:
                /* A header name has no escapes: a backslash in one is
                 * just a character of the file name. */
                if (at == in::LITERAL && out[i] == '\\') {
                    ++i;
                    continue;
                }

                if (out[i] == close)
                    at = in::CODE;
                continue;

            case in::CODE:
                break;
            }

            if (out[i] == '/' && peek(i) == '/') {
                at = in::LINE_COMMENT;
                out[i] = ' ';
            } else if (out[i] == '/' && peek(i) == '*') {
                /* Both characters are stepped over here, so that the
                 * "*" that opens a block comment is never also taken
                 * for the one that closes it: "/" "*" "/" is a comment
                 * that is still open, and what follows it up to a "*"
                 * "/" of its own is still comment. */
                comment = 1;
                out[i] = ' ';
                out[++i] = ' ';
            } else if ((out[i] == '"' || out[i] == '<')
                       && opens_header_name(i)) {
                at = in::HEADER;
                close = out[i] == '<' ? '>' : '"';
            } else if (out[i] == '"') {
                at = in::LITERAL;
                close = '"';
            } else if (out[i] == '\'' && separates_digits(i) == false) {
                at = in::LITERAL;
                close = '\'';
            }
        }

        return true;
    };

    /* Labelling an "#else" or an "#endif" with the condition it
     * belongs to is a habit carried over from C, and there is more
     * than one way of writing the label.  In a script it is a shell
     * comment, "#endif # WITH_EXTRAS"; in C it is either a comment,
     * which has been blanked out by the time a line gets here, or the
     * bare name, "#endif WITH_EXTRAS", which is older than "//" and
     * which the compiler still reads as an "#endif", warning about the
     * rest.  pbashc only looks at the start of the line for these two
     * as well, so in neither language does what follows the keyword
     * change what the line does.
     *
     * Refusing it here instead left a source the compiler builds as
     * one the project couldn't be configured around, and the warning
     * is the compiler's to give: it sees the line on every build,
     * where this only sees it when the scan runs.  So the "#else"
     * and "#endif" below take no notice of anything after the
     * keyword. */

    /* "#ifdef NAME" asks about one name.  The compiler reads a C line
     * with more after the name -- "#ifdef VERBOSE LOGGING", or
     * "#ifdef VERBOSE(x)", or "#ifdef VERBOSE;" -- as a question
     * about the identifier the line starts with, warning about the
     * rest, and the scan has to answer the same question or it
     * follows the other branch.  So the name ends where the
     * identifier does, at the first character that can't be part of
     * one, and not merely at the first space: cut at the space,
     * "VERBOSE(x)" is a name nothing defines, and the scan quietly
     * takes the branch the compiler skips.  Handed whole to the
     * expression reader it wasn't a question at all: "defined(VERBOSE
     * LOGGING)" is no expression, and the reader aborted on it
     * without saying which file it was in.
     *
     * Only for C.  pbashc compares everything after the keyword with
     * the names it was given, so in a script the identifier is not
     * the question pbashc asks, and answering it here would only
     * trade one disagreement for another. */
    const auto ifdef_name = [&](const std::string& rest) {
        if (language != pinclude::syntax::C)
            return rest;

        size_t end = 0;
        while (end < rest.size()
               && (isalnum((unsigned char)rest[end]) || rest[end] == '_'))
            end++;
        return rest.substr(0, end);
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

            /* Inside a branch that isn't taken the compiler evaluates
             * nothing, not even an "#if" it couldn't make sense of,
             * and "#if 0" is exactly where code that is off for now
             * goes.  Whatever the test says, everything up to the
             * matching "#endif" is off, so there is no reason to work
             * it out -- and an expression this reader can't follow is
             * no reason to stop reading a file the compiler builds. */
            if (state_stack.top() != state::OUTPUT) {
                state_stack.push(state::DEAD);
                return;
            }

            auto resolved = resolve_pp_function(rest, defines);
            push_conditional(resolved);
        }, bare_directives);

        check_line(line, "ifdef", [&](std::string rest) {
            auto resolved = resolve_pp_function("defined(" + ifdef_name(rest) + ")", defines);
            push_conditional(resolved);
        }, bare_directives);

        check_line(line, "ifndef", [&](std::string rest) {
            auto resolved = resolve_pp_function("!defined(" + ifdef_name(rest) + ")", defines);
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

        /* A name that has been "#undef"ed is no longer defined, and an
         * "#ifdef" of it after that is off -- whether a "#define"
         * further up made it or a "-D" in COMPILEOPTS did.  Left
         * defined, the scan follows an include the compiler never
         * sees, and the source behind it gets built and linked into a
         * program that never asked for it.
         *
         * Only where lines are live: an "#undef" in a branch that
         * isn't taken undefines nothing, just as an include there
         * includes nothing.  And only in C, since pbashc reads neither
         * "#define" nor "#undef" in a script -- the names a script
         * sees are the "-D"s and nothing else, and taking one away
         * here would leave out an include pbashc pastes in. */
        check_line(line, "undef", [&](std::string rest) {
            if (language != pinclude::syntax::C)
                return;
            if (state_stack.top() != state::OUTPUT)
                return;

            auto after = rest.find_first_of(" \t");
            defines.erase(rest.substr(0, after));
        }, bare_directives);

        check_line(line, "else", [&](std::string) {
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
            case state::DONE:
                state_stack.push(state::DONE);
                break;
            case state::DEAD:
                state_stack.push(state::DEAD);
                break;
            }
        }, bare_directives);

        /* An "#elif" ends the branch before it and opens another in the
         * same conditional, and which one is read is the first whose
         * test holds: once a branch has been taken, every one after it
         * is off, however its own test comes out.  Without this the
         * lines after an "#elif" went by the "#if" that opened the
         * chain, so an include in the "#elif" that was taken went
         * unlisted and one after a taken "#if" was followed.
         *
         * Only in C.  pbashc knows nothing of an "#elif": to it the
         * line is a comment and the lines after it go by the "#ifdef"
         * above, and the list of what a script reads has to be found
         * the way pbashc finds it.
         *
         * The test is only worked out for a branch that could be the
         * one taken.  After a branch has been, or inside one that is
         * off, the compiler doesn't evaluate it either, and an
         * expression this reader can't follow is no reason to stop. */
        check_line(line, "elif", [&](std::string rest) {
            if (language != pinclude::syntax::C)
                return;

            /* The bottom of the stack is the file itself rather than a
             * conditional, and there is nothing for an "#elif" there
             * to be the next branch of.  Taken as one, it would turn
             * off the rest of the file. */
            if (state_stack.size() <= 1) {
                std::cerr << filename << ":" << lineno << ": '"
                          << raw << "' has no '#if' before it\n"
                          << "  an '#elif' is the next branch of an"
                          << " '#if', '#ifdef' or '#ifndef' that is"
                          << " still open\n"
                          << "  open the conditional before it, or write"
                          << " '#if' if this is where it starts\n";
                abort();
            }

            auto ss = state_stack.top();
            state_stack.pop();
            switch (ss) {
            case state::OUTPUT:
            case state::DONE:
                state_stack.push(state::DONE);
                break;
            case state::ELSE:
                if (rest == "") {
                    std::cerr << filename << ":" << lineno << ": '"
                              << raw << "' has no expression\n"
                              << "  write the test this branch is"
                              << " taken on after it, or '#else' if it"
                              << " is taken whenever the ones before it"
                              << " aren't\n";
                    abort();
                }

                state_stack.push(resolve_pp_function(rest, defines)
                                 ? state::OUTPUT
                                 : state::ELSE);
                break;
            case state::DEAD:
                state_stack.push(state::DEAD);
                break;
            }
        }, bare_directives);

        check_line(line, "endif", [&](std::string) {
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

            /* Anything but a quote or a '<' after the keyword is a
             * computed include, "#include NAME" with NAME a macro
             * that expands to one of the spellings above.  That is
             * standard C, and how a project picks a configuration
             * header without an "#ifdef" ladder, but there is nothing
             * here to expand it with: what is tracked is which names
             * are defined rather than what they are defined as.  A
             * header the scan can't name is one it can't list, so the
             * line is passed over and the rest of the file read as
             * usual.  That is no change from what a script gets:
             * pbashc drops every "#include" line from its output, and
             * one with no quote or '<' after it pastes nothing in, so
             * passing it over here includes nothing either way.
             *
             * It costs two things in C.  The header behind the macro
             * isn't a prerequisite of the object, so an edit to it
             * alone doesn't rebuild one.  And the source that
             * implements that header is never found, since finding it
             * is what listing the header does, so unless something
             * else brings it in the configure succeeds and the link
             * then fails.  Including the header by name as well pays
             * for both; listing its source in SOURCES pays only for
             * the link.  Aborting cost the whole project, in two
             * lines that named no file. */
            if (rest.empty() || (rest[0] != '<' && rest[0] != '"'))
                return;

            auto rest_path = rest[0] == '<'
                ? delimited('>')
                : delimited('"');

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

            /* A file the build is going to make is where it is going
             * to be, as far as this search is concerned, whether it
             * has been made yet or not -- see promised in the header.
             * Asked in the same breath as whether a file is there,
             * rather than after the whole search has failed, so that
             * it wins against anything later down the path. */
            auto findable = [&](const std::string& path) {
                return includable(path)
                    || promised.count(strip_dd(path)) > 0;
            };

            /* The C preprocessor looks beside the includer only for
             * the quoted spelling: "#include <time.h>" goes straight
             * to the include path and on to the system's headers, so
             * a project's own src/time.h is no part of what it reads.
             * Looking beside the includer anyway would list that
             * header as a dependency, and the source next to it would
             * be compiled and linked into a program that never asked
             * for it.  pbashc is another matter: it reads the angled
             * spelling as the quoted one, so a script's angled include
             * is still looked for beside the script. */
            auto searches_includer = rest[0] == '"'
                || language != pinclude::syntax::C;

            /* The same goes for an "-iquote" directory, and for the
             * same reason: the angled spelling never looks there, so
             * a header in one is no answer to "#include <extra.h>"
             * however early its flag was written, and following it
             * lists the wrong header and links the source behind it.
             * Whichever spelling looks beside the includer is the one
             * that looks in the quote-only directories after that. */
            auto search_dirs = searches_includer
                ? include_dirs.quoted()
                : include_dirs.both;

            /* Every place tried and passed over on the way, which is
             * every place a file could appear and change what this
             * include reads -- see on_missed in the header.  Only the
             * ones with nothing there at all: lstat() rather than
             * stat(), so that a dangling link, which the search passes
             * over and which make's "$(wildcard)" may or may not see,
             * is no more a reason to look again than a directory is. */
            auto missed = std::vector<std::string>();
            auto miss = [&](const std::string& path) {
                struct stat st;
                if (on_missed != nullptr && lstat(path.c_str(), &st) != 0)
                    missed.push_back(strip_dd(path));
            };

            auto full_path = [&]() {
                auto cwd_relative = get_relative_cwd(filename) + rest_path;
                if (searches_includer) {
                    if (findable(cwd_relative))
                        return option<std::string>(strip_dd(cwd_relative));
                    miss(cwd_relative);
                }

                for (const auto& dir: search_dirs) {
                    auto check = dir + "/" + rest_path;
                    if (findable(check))
                        return option<std::string>(strip_dd(check));
                    miss(check);
                }

                return option<std::string>();
            }();

            for (const auto& path: missed)
                on_missed(path);

            if (skip_missing_files == false && full_path.valid() == false) {
                std::cerr << "Unable to open file: " << rest_path << "\n";
                abort();
            }

            /* Named but not followed: a promise that has not been kept
             * yet has no lines in it to read. */
            auto unmade = full_path.valid() == true
                && includable(full_path.data()) == false;

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

                if (unmade == true)
                    return;

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
                    strict_directives,
                    promised,
                    on_missed
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

/* Whether what follows a Perl "<<" (and any "~") at "i" is a
 * terminator, which is a quoted string with or without blanks before
 * it or a word written right against the "<<".  A backslash in that
 * place is the old spelling of single quotes, and still a heredoc. */
static bool perl_heredoc_follows(const std::string& line, size_t i)
{
    if (i < line.size()
        && (isalnum((unsigned char)line[i]) || line[i] == '_'
            || line[i] == '\\'))
        return true;

    while (i < line.size() && isspace((unsigned char)line[i]))
        ++i;

    return i < line.size()
        && (line[i] == '"' || line[i] == '\'' || line[i] == '`');
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

        /* Perl reads a terminator in fewer places than the shell does.
         * A quoted one may have blanks before it, but an unquoted one
         * has to be written right against the "<<", and has to be a
         * word: "1 << 4" is a shift, and so is "$x <<= 2" with its
         * "=".  Reading either with the shell's rule opens a heredoc
         * that no line ends, and every include after it is lost.  The
         * character after the "<<" is looked at again, as the one
         * after a delimiter is. */
        if (language == pinclude::syntax::PERL
            && perl_heredoc_follows(line, i) == false) {
            --i;
            continue;
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
