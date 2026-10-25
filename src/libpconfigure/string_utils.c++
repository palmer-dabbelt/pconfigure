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

#include "string_utils.h++"
#include <cctype>
#include <iostream>
#include <sstream>
using namespace string_utils;

std::string string_utils::clean_white(const std::string& in)
{
    /* One pass over the string, by its size.  Every Configfile line
     * comes through here more than once, and lines may be as long as
     * their author made them, so this has to cost no more than
     * reading the line does: asking strlen() for the length on every
     * character, as this used to, made a line of a couple of
     * megabytes take minutes.  Going by size() rather than looking
     * for a terminator also means a NUL is just another character
     * here, rather than the place the line silently ends -- whether a
     * NUL belongs in a line at all is for whoever reads the line to
     * decide, not for the code that tidies its spaces.
     *
     * Leading white space is dropped by starting as though the last
     * character were white, and each run after that becomes a single
     * space, which can leave one trailing space for the end to trim.
     * isspace() is only defined for values an unsigned char can hold,
     * so a byte with its top bit set has to be widened as one rather
     * than sign-extended. */
    auto out = std::string();
    out.reserve(in.size());

    auto white = true;
    for (const auto& c: in) {
        auto was_white = white;
        white = isspace(static_cast<unsigned char>(c));

        if (white && was_white)
            continue;

        out += white ? ' ' : c;
    }

    if (!out.empty() && out.back() == ' ')
        out.pop_back();

    return out;
}

#ifdef TEST_CLEAN_WHITE
int main(int argc, char **argv)
{
    if (argc != 2)
        return -1;

    std::cout << string_utils::clean_white(argv[1]).c_str() << "\n";
    return 0;
}
#endif

std::vector<std::string> string_utils::split_char(const std::string& in,
                                                  const std::string& delims)
{
    std::vector<std::string> out;

    size_t offset = 0;
    while (offset != std::string::npos) {
        auto end = in.find_first_of(delims, offset);
        if (end == std::string::npos)
            break;

        out.push_back(std::string(in, offset, end - offset));
        offset = end + 1;
    }

    if (offset != std::string::npos)
        out.push_back(std::string(in, offset));

    return out;
}

#ifdef TEST_STRIP_CHAR
int main(int argc, char **argv)
{
    if (argc != 3)
        return -1;

    for (const auto& spl: string_utils::split_char(argv[1], argv[2]))
        std::cout << spl << "\n";

    return 0;
}
#endif

std::vector<std::string> string_utils::shell_words(const std::string& in)
{
    auto out = std::vector<std::string>();
    auto word = std::string();
    auto in_word = false;

    /* The quote that's open, or nothing when none is.  A word that
     * opens a quote and never closes it runs to the end of the line,
     * which is a line the shell would refuse to run; the compiler's
     * complaint about it says more than one from here could. */
    auto quote = '\0';

    for (size_t i = 0; i < in.size(); ++i) {
        if (quote == '\'') {
            word += in[i];
            if (in[i] == '\'')
                quote = '\0';
        } else if (in[i] == '\\' && i + 1 < in.size()) {
            word += in[i];
            word += in[i+1];
            in_word = true;
            ++i;
        } else if (quote == '"') {
            word += in[i];
            if (in[i] == '"')
                quote = '\0';
        } else if (in[i] == '\'' || in[i] == '"') {
            word += in[i];
            quote = in[i];
            in_word = true;
        } else if (isspace(in[i])) {
            if (in_word == true)
                out.push_back(word);
            word = "";
            in_word = false;
        } else {
            word += in[i];
            in_word = true;
        }
    }

    if (in_word == true)
        out.push_back(word);

    return out;
}

std::string string_utils::shell_unescape(const std::string& in)
{
    auto out = std::string();
    auto quote = '\0';

    for (size_t i = 0; i < in.size(); ++i) {
        if (quote == '\'') {
            if (in[i] == '\'')
                quote = '\0';
            else
                out += in[i];
        } else if (quote == '"') {
            /* Inside double quotes a backslash only means something in
             * front of the characters that would otherwise do
             * something there; anywhere else it is text, as it is in
             * -DPATH="C:\dir". */
            if (in[i] == '"')
                quote = '\0';
            else if (in[i] == '\\' && i + 1 < in.size()
                     && std::string("$`\"\\").find(in[i+1]) != std::string::npos)
                out += in[++i];
            else
                out += in[i];
        } else if (in[i] == '\'' || in[i] == '"') {
            quote = in[i];
        } else if (in[i] == '\\' && i + 1 < in.size()) {
            out += in[++i];
        } else {
            out += in[i];
        }
    }
    return out;
}

bool string_utils::has_extension(const std::string& name,
                                 const std::string& extension)
{
    if (name.size() <= extension.size())
        return false;

    return name.compare(name.size() - extension.size(),
                        extension.size(),
                        extension) == 0;
}

std::string string_utils::join(const std::vector<std::string>& in,
                               const std::string& delim)
{
    std::ostringstream ss;
    for(auto i = in.size()*0; i < in.size(); ++i) {
        if (i != 0)
            ss << delim;
        ss << in[i];
    }
    return ss.str();
}

/* Computes a simple hash code for a vector of strings. */
std::string string_utils::hash(const std::vector<std::string>& in)
{
    unsigned long hash = 5381;

    for (const auto& str: in)
        for (const auto& chr: str)
            hash = ((hash << 5) + hash) + chr;

    return std::to_string(hash);
}

std::string string_utils::quoted(const std::string& in)
{
    auto out = std::string("'");
    for (const auto& c: in) {
        if (c == '\'')
            out += "'\\''";
        else
            out += c;
    }
    return out + "'";
}

std::string string_utils::unexpanded(const std::string& in)
{
    auto out = std::string();
    for (const auto& c: in) {
        if (c == '$')
            out += "$$";
        else
            out += c;
    }
    return out;
}

std::string string_utils::echoed(const std::string& in)
{
    return quoted(unexpanded(in));
}
