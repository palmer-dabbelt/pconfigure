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
#include <unistd.h>

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs,
                   std::vector<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files,
                   bool bare_directives,
                   pinclude::directive_callback on_directive)
{
    std::unordered_set<std::string> define_set;
    for (const auto& define: defines)
        define_set.insert(define);

    return list(filename,
                include_dirs,
                define_set,
                callback,
                skip_missing_files,
                bare_directives,
                on_directive);
}

enum class state {
    OUTPUT,
    ELSE,
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
};

static void open_heredocs(const std::string& line,
                          std::vector<heredoc>& open);

static bool closes_heredoc(const std::string& line, const heredoc& open);

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
                           std::function<int(std::string)> callback,
                           bool skip_missing_files,
                           bool bare_directives,
                           const pinclude::directive_callback& on_directive);

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs_without_cwd,
                   std::unordered_set<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files,
                   bool bare_directives,
                   pinclude::directive_callback on_directive)
{
    return list_overwrite_defines(
        filename,
        include_dirs_without_cwd,
        defines,
        callback,
        skip_missing_files,
        bare_directives,
        on_directive
    );
}

int list_overwrite_defines(std::string filename,
                           std::vector<std::string> include_dirs,
                           std::unordered_set<std::string>& defines,
                           std::function<int(std::string)> callback,
                           bool skip_missing_files,
                           bool bare_directives,
                           const pinclude::directive_callback& on_directive)
{
    std::ifstream file(filename);
    std::string line;

    std::stack<state> state_stack;
    state_stack.push(state::OUTPUT);

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

    static const auto next_logical_line = [](std::ifstream& file, std::string& out,
                                             int& comment, int& lineno) {
        std::string line;
        if (!std::getline(file, line))
            return false;
        out = line;
        lineno++;

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

    /* Counted up as a line is read rather than after it has been
     * dealt with, so the count starts one behind what it names: the
     * first line of a file is line 1, and the counter has to have
     * reached it by the time anything is said about that line. */
    int lineno = 0;
    int comment = 0;
    std::vector<heredoc> heredocs;
    while (next_logical_line(file, line, comment, lineno)) {
        /* A heredoc's body is text the script writes out rather than
         * script, so an "#include" in one is a line meant for
         * whatever compiles the file being written and not a file
         * this one reads.  Counted as a dependency it makes make
         * rebuild a script whenever some file it only ever mentions
         * changes, and it disagrees with pbashc, which leaves the
         * same line alone.
         *
         * Only for a script: heredocs are a thing shells have, and
         * "bare_directives" is already the question of whether this
         * is reading one. */
        if (bare_directives == true) {
            if (heredocs.empty() == false) {
                if (closes_heredoc(line, heredocs.front()) == true)
                    heredocs.erase(heredocs.begin());
                continue;
            }

            open_heredocs(line, heredocs);
        }

        check_line(line, "if", [&](std::string rest) {
            auto resolved = resolve_pp_function(rest, defines);
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
        }, bare_directives);

        check_line(line, "ifdef", [&](std::string rest) {
            auto resolved = resolve_pp_function("defined(" + rest + ")", defines);
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
        }, bare_directives);

        check_line(line, "ifndef", [&](std::string rest) {
            auto resolved = resolve_pp_function("!defined(" + rest + ")", defines);
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
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
            }
        }, bare_directives);

        check_line(line, "endif", [&](std::string rest) {
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

            auto rest_path = [&]() {
                if (rest[0] == '<')
                    return rest.substr(1, rest.size() - 2);
                if (rest[0] == '"')
                    return rest.substr(1, rest.size() - 2);

                std::cerr << "Unable to parse line " << line << "\n";
                std::cerr << "  Unknown include format, expected < or \"" << "\n";
                abort();
            }();

            auto full_path = [&]() {
                auto cwd_relative = get_relative_cwd(filename) + rest_path;
                if (access(cwd_relative.c_str(), R_OK) == 0)
                    return option<std::string>(strip_dd(cwd_relative));

                for (const auto& dir: include_dirs) {
                    auto check = dir + "/" + rest_path;
                    if (access(check.c_str(), R_OK) == 0)
                        return option<std::string>(strip_dd(check));
                }

                return option<std::string>();
            }();

            if (skip_missing_files == false && full_path.valid() == false) {
                std::cerr << "Unable to open file: " << rest_path << "\n";
                abort();
            }

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
                    callback,
                    skip_missing_files,
                    bare_directives,
                    on_directive
                );
                if (rout != 0) {
                    std::cerr << "Early out no longer supported in pinclude::list\n";
                    abort();
                }
            }
        }, bare_directives);
    }
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

/* Adds the heredocs a line opens to the ones still waiting for a
 * body, in the order those bodies arrive.
 *
 * What this recognizes is the shape of a redirection and nothing
 * more, which is the same reading pbashc does -- the two have to
 * agree about where a body starts and ends, or the file make is told
 * about is not the file that gets compiled. */
void open_heredocs(const std::string& line, std::vector<heredoc>& open)
{
    char quoted = '\0';

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
         * rather than a redirection: "$((1<<20))" is arithmetic. */
        if (i > 0 && (isalnum((unsigned char)line[i - 1])
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

        while (i < line.size() && isspace((unsigned char)line[i]))
            ++i;

        /* Quoting the delimiter asks for a body the shell expands
         * nothing in, which makes no difference to where that body
         * ends -- the word inside the quotes is what ends it either
         * way. */
        char delim_quote = '\0';
        if (i < line.size() && (line[i] == '\'' || line[i] == '"')) {
            delim_quote = line[i];
            ++i;
        }

        auto start = i;
        while (i < line.size()
               && (delim_quote == '\0'
                   ? ends_shell_word(line[i]) == false
                   : line[i] != delim_quote))
            ++i;

        /* A "<<" with nothing after it isn't a script the shell would
         * run either, so there's nothing here to be right about. */
        if (i == start)
            continue;

        open.push_back(heredoc{line.substr(start, i - start), strip_tabs});
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

    auto end = line.size();
    while (end > begin && (line[end - 1] == '\r' || line[end - 1] == '\n'))
        --end;

    return line.compare(begin, end - begin, open.delim) == 0;
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

    /* By the time a line gets here its comments have already been
     * blanked out, so looking for the start of one finds nothing and
     * what a trailing comment leaves behind is whitespace.  That has to
     * go: the include parser reads the last character of what it's
     * handed as the closing quote, and trailing space makes it read a
     * quote that is still in the middle of the string. */
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
