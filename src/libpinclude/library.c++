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
#include <fstream>
#include <stack>
#include <iostream>
#include <fcntl.h>
#include <unistd.h>

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs,
                   std::vector<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files)
{
    std::unordered_set<std::string> define_set;
    for (const auto& define: defines)
        define_set.insert(define);

    return list(filename,
                include_dirs,
                define_set,
                callback,
                skip_missing_files);
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

static void check_line(
    const std::string& line,
    const std::string& pp, 
    const std::function<void(std::string)> on_match
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
                           bool skip_missing_files);

int pinclude::list(std::string filename,
                   std::vector<std::string> include_dirs_without_cwd,
                   std::unordered_set<std::string> defines,
                   std::function<int(std::string)> callback,
                   bool skip_missing_files)
{
    return list_overwrite_defines(
        filename,
        include_dirs_without_cwd,
        defines,
        callback,
        skip_missing_files
    );
}

int list_overwrite_defines(std::string filename,
                           std::vector<std::string> include_dirs,
                           std::unordered_set<std::string>& defines,
                           std::function<int(std::string)> callback,
                           bool skip_missing_files)
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

        while (line[line.size() - 1] == '\\') {
            if (!std::getline(file, line))
                return true;

            out = out.substr(0, out.size() - 1) + line;
        }

        for (size_t i = 0; i < out.size(); ++i) {
            bool was_comment = comment > 0;
            if (comment == 1)
               comment = 0;
            if (out[i] == '/' && out[i+1] == '/')
              comment = 2;
            if (out[i] == '/' && out[i+1] == '*')
              comment = 2;
            if (out[i] == '*' && out[i+1] == '/')
              comment = 1;

            if (was_comment || comment > 0)
              out[i] = ' ';
        }

        return true;
    };

    int lineno = 1;
    int comment = 0;
    while (next_logical_line(file, line, comment, lineno)) {
        check_line(line, "if", [&](std::string rest) {
            auto resolved = resolve_pp_function(rest, defines);
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
        });

        check_line(line, "ifdef", [&](std::string rest) {
            auto resolved = resolve_pp_function("defined(" + rest + ")", defines);
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
        });

        check_line(line, "ifndef", [&](std::string rest) {
            auto resolved = resolve_pp_function("!defined(" + rest + ")", defines);
            state_stack.push(resolved ? state::OUTPUT : state::ELSE);
        });

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
        });

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
        });

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
        });

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
                    skip_missing_files
                );
                if (rout != 0) {
                    std::cerr << "Early out no longer supported in pinclude::list\n";
                    abort();
                }
            }
        });
    }
    return 0;
}

static void check_line(const std::string& line, const std::string& pp, const std::function<void(std::string)> on_match)
{
    size_t i = 0;

    /* The first non-whitespace character must be a # */
    while (i < line.size() && isspace(line[i]))
        i++;
    if (line[i] != '#')
        return;

    /* After the # there can be any number of spaces, so we just skip them. */
    i++;
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
    if (!isspace(line[i + pp.size()]))
        return;

    /* Here we strip the extra whitespace before after the directive before
     * calling the given function on matches. */
    i += pp.size();
    while (i < line.size() && isspace(line[i]))
        i++;

    /* Checks to see if there's any comments, and strip those. */
    auto comment_i = i;
    while (comment_i < line.size()) {
        if (line.substr(comment_i, 2) == "//")
            break;
        if (line.substr(comment_i, 2) == "/*")
            break;
        comment_i++;
    }

    return on_match(line.substr(i, comment_i - i));
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
