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

#include "file_utils.h++"
#include "vector_util.h++"
#include <sys/stat.h>
#include <sys/types.h>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <sstream>
using namespace file_utils;

#ifndef LINE_MAX
#define LINE_MAX 1024
#endif

std::vector<struct line_and_number> file_utils::readlines_and_numbers(FILE *f)
{
    char line[LINE_MAX];
    size_t num = 1;
    std::vector<struct line_and_number> out;

    while (std::fgets(line, LINE_MAX, f) != NULL) {
        struct line_and_number lan;
        lan.line = line;
        lan.number = num;
        out.push_back(lan);
        num++;
    }

    return out;
}

std::vector<std::string> file_utils::readlines(FILE *f)
{
    return vector_util::map(readlines_and_numbers(f),
                            [](struct line_and_number ln)
                            {
                                return ln.line;
                            });
}

std::vector<std::string>
file_utils::execlines(std::string path, std::vector<std::string> args)
{
    std::ostringstream cmd;

    /* Whatever was handed in goes to the shell exactly as it was
     * written.  Quoting it here would mean deciding that it names one
     * program, and a caller that has something to say about the
     * directory the program runs in has already written a compound
     * command -- which is a perfectly good thing to hand a shell and
     * not a thing that has a name.  The one caller quotes the
     * program itself, which is where that belongs: it's the part
     * that's a path. */
    cmd << path << " ";
    for (const auto& arg: args)
        cmd << "\"" << arg << "\"" << " ";

    std::vector<std::string> out;
    auto file = popen(cmd.str().c_str(), "r");
    if (file == NULL) {
        std::cerr << "can't run '" << cmd.str() << "': "
                  << strerror(errno) << "\n";
        abort();
    }

    char *lineptr = NULL;
    size_t n = 0;
    while (getline(&lineptr, &n, file) > 0) {
        auto line = std::string(lineptr);
        line = line.substr(0, line.size()-1);
        out.push_back(line);
    }

    free(lineptr);

    /* The shell has already said what went wrong on stderr, but it
     * said it about the command rather than about the run: without
     * this the only other thing anybody gets is a signal. */
    auto status = pclose(file);
    if (status != 0) {
        std::cerr << "'" << cmd.str() << "' failed with status "
                  << std::to_string(status) << "\n";
        abort();
    }

    return out;
}

std::string file_utils::normalize_directory(const std::string& path)
{
    auto out = normalize_path(path);

    if (out == ".")
        return "";
    if (out.size() > 0 && out[out.size() - 1] != '/')
        out += "/";
    return out;
}

std::string file_utils::normalize_path(const std::string& path)
{
    auto absolute = path.size() > 0 && path[0] == '/';
    auto trailing = path.size() > 0 && path[path.size() - 1] == '/';

    auto parts = std::vector<std::string>();
    auto part = std::string();
    for (size_t i = 0; i <= path.size(); ++i) {
        if (i < path.size() && path[i] != '/') {
            part += path[i];
            continue;
        }

        if (part.size() == 0 || part == ".") {
            /* "a//b" and "a/./b" are just "a/b". */
        } else if (part == ".."
                   && parts.size() > 0
                   && parts.back() != "..") {
            parts.pop_back();
        } else {
            parts.push_back(part);
        }

        part = "";
    }

    auto out = std::string();
    for (size_t i = 0; i < parts.size(); ++i) {
        if (i > 0)
            out += "/";
        out += parts[i];
    }

    if (absolute == true)
        out = "/" + out;
    if (trailing == true && out.size() > 0 && out != "/")
        out += "/";
    if (out.size() == 0 && absolute == false)
        out = trailing ? "" : ".";

    return out;
}

/* Splits a normalized directory into its components.  There are no
 * empty ones and no "." ones to worry about, since normalizing is
 * what takes those out. */
static std::vector<std::string> components(const std::string& dir)
{
    auto out = std::vector<std::string>();
    auto part = std::string();

    for (const auto& c: dir) {
        if (c != '/') {
            part += c;
            continue;
        }

        out.push_back(part);
        part = "";
    }

    return out;
}

std::string file_utils::relative_directory(const std::string& from,
                                           const std::string& to)
{
    auto here = components(normalize_directory(from));
    auto there = components(normalize_directory(to));

    /* Everything the two have in common is already behind whoever is
     * standing in "from", so none of it gets walked either way. */
    size_t same = 0;
    while (same < here.size()
           && same < there.size()
           && here[same] == there[same])
        same++;

    /* Up out of what's left of "from", then down into what's left of
     * "to".  A normalized directory has no ".." in it, so climbing is
     * only ever what this puts there and the answer is normalized
     * too. */
    auto out = std::string();
    for (size_t i = same; i < here.size(); ++i)
        out += "../";
    for (size_t i = same; i < there.size(); ++i)
        out += there[i] + "/";

    return out;
}

bool file_utils::mkdir_p(const std::string& path)
{
    if (path.size() == 0)
        return true;

    struct stat buf;
    if (stat(path.c_str(), &buf) == 0)
        return S_ISDIR(buf.st_mode);

    /* Whatever is above this has to exist first, which is the whole
     * of what "-p" means.  A path with no '/' left in it has nothing
     * above it inside this tree, and the recursion stops on the empty
     * string above rather than on a special case here. */
    auto slash = path.rfind('/');
    if (slash != std::string::npos)
        if (mkdir_p(path.substr(0, slash)) == false)
            return false;

    if (mkdir(path.c_str(), 0777) == 0)
        return true;

    /* Somebody else may have made it in between, which is a success:
     * what was asked for was that the directory exist.
     *
     * Whether they did or not, asking costs the errno that says why
     * the mkdir failed -- and that errno is the whole of what the
     * caller has to tell somebody.  Put back the real one, since a
     * permission problem reported as a missing directory sends
     * whoever reads it looking for a directory that is right there. */
    auto why = errno;
    auto made = stat(path.c_str(), &buf) == 0 && S_ISDIR(buf.st_mode);
    if (made == false)
        errno = why;

    return made;
}

bool file_utils::write_if_changed(const std::string& path,
                                  const std::string& contents)
{
    auto read = std::string();

    auto in = fopen(path.c_str(), "r");
    if (in != NULL) {
        char buffer[4096];
        size_t got;
        while ((got = fread(buffer, 1, sizeof(buffer), in)) > 0)
            read.append(buffer, got);
        fclose(in);

        if (read == contents)
            return true;
    }

    auto slash = path.rfind('/');
    if (slash != std::string::npos)
        if (mkdir_p(path.substr(0, slash)) == false)
            return false;

    auto out = fopen(path.c_str(), "w");
    if (out == NULL)
        return false;

    auto wrote = contents.size() == 0
        || fwrite(contents.data(), 1, contents.size(), out) == contents.size();

    return fclose(out) == 0 && wrote;
}
