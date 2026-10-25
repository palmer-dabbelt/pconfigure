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
#include "string_utils.h++"
#include "vector_util.h++"
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>
using namespace file_utils;

std::vector<struct line_and_number> file_utils::readlines_and_numbers(FILE *f)
{
    size_t num = 1;
    std::vector<struct line_and_number> out;

    /* One physical line is one entry, however long it is.  This used
     * to read into a LINE_MAX buffer with fgets(), which hands a
     * longer line back in pieces: each piece then became a command of
     * its own with a line number of its own, so a long COMPILEOPTS
     * lost everything past the cut and every diagnostic after it
     * named the wrong line.  Nothing promises a Configfile's lines
     * are short -- a generator printing every define it found is
     * exactly what makes a long one -- so getline() grows the buffer
     * to fit instead. */
    char *lineptr = NULL;
    size_t n = 0;
    ssize_t length;
    while ((length = getline(&lineptr, &n, f)) > 0) {
        struct line_and_number lan;
        lan.line = std::string(lineptr, length);
        lan.number = num;
        out.push_back(lan);
        num++;
    }

    free(lineptr);
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
file_utils::execlines(std::string path,
                      std::vector<std::string> args,
                      const std::function<void(const std::string&)>& failed)
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
        failed(std::string("could not be started: ") + strerror(errno));
        abort();
    }

    /* The newline is taken off only when there is one.  The last line
     * of what a program prints need not end in one -- printf with no
     * "\n" is the ordinary way a shell script prints a single name --
     * and getline() hands that line back exactly as it was printed.
     * Chopping the final byte unconditionally took the last letter of
     * the path off instead, so a "--deps" answer of "src/answer.txt"
     * became a rule naming "src/answer.tx", a file that does not
     * exist, and make stopped on it.  The length getline() returns is
     * used rather than strlen(), so that a stray NUL in the output
     * does not end the line early either. */
    char *lineptr = NULL;
    size_t n = 0;
    ssize_t length;
    while ((length = getline(&lineptr, &n, file)) > 0) {
        if (lineptr[length - 1] == '\n')
            length--;
        out.push_back(std::string(lineptr, length));
    }

    free(lineptr);

    /* The shell has already said what went wrong on stderr, but it
     * said it about the command rather than about the run, and it
     * can't say which Configfile line the command came from -- so the
     * caller gets told, and writes the error.  The abort() after it is
     * a backstop for a caller that forgot to stop: carrying on with
     * whatever half an answer was read would be worse than stopping
     * without a good message. */
    auto status = pclose(file);
    if (status != 0) {
        failed(describe_wait_status(status));
        abort();
    }

    return out;
}

std::string file_utils::describe_wait_status(int status)
{
    if (status == -1)
        return std::string("could not be waited for: ") + strerror(errno);

    /* The two codes the shell keeps for itself are spelled out, since
     * they are the shell talking rather than the command: 127 is what
     * it exits with when there was nothing to run, and 126 when there
     * was something but it couldn't be executed.  A command is free to
     * exit with either of them on its own account, which is why the
     * number is kept rather than replaced. */
    if (WIFEXITED(status)) {
        auto code = WEXITSTATUS(status);
        auto out = "exited with status " + std::to_string(code);
        if (code == 127)
            out += ", which is the shell saying it found nothing to run";
        if (code == 126)
            out += ", which is the shell saying it could not execute it";
        return out;
    }

    if (WIFSIGNALED(status)) {
        auto sig = WTERMSIG(status);
        return "was killed by signal " + std::to_string(sig)
            + " (" + strsignal(sig) + ")";
    }

    return "stopped with wait status " + std::to_string(status);
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

std::string file_utils::reroot(const std::string& base,
                               const std::string& dir)
{
    if (dir.size() == 0 || dir[0] == '/')
        return dir;
    return base + dir;
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

bool file_utils::says(const std::string& path, const std::string& contents)
{
    auto in = fopen(path.c_str(), "r");
    if (in == NULL)
        return false;

    auto read = std::string();
    char buffer[4096];
    size_t got;
    while ((got = fread(buffer, 1, sizeof(buffer), in)) > 0)
        read.append(buffer, got);
    fclose(in);

    return read == contents;
}

bool file_utils::write_if_changed(const std::string& path,
                                  const std::string& contents)
{
    if (says(path, contents) == true)
        return true;

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

bool file_utils::no_newer_than(const std::string& path,
                               const std::string& like)
{
    struct stat buf;
    if (stat(like.c_str(), &buf) != 0)
        return true;

    /* The whole timestamp rather than its seconds, since make
     * compares them down to the nanosecond where the system keeps
     * them, and a record backdated to the second before its output
     * is still a record newer than nothing.  The access time is left
     * as it is: nothing here asks about it. */
    struct timespec times[2];
    times[0].tv_sec = 0;
    times[0].tv_nsec = UTIME_OMIT;
#if defined(__APPLE__)
    times[1] = buf.st_mtimespec;
#else
    times[1] = buf.st_mtim;
#endif

    return utimensat(AT_FDCWD, path.c_str(), times, 0) == 0;
}

/* One list for the whole run rather than one per project, because
 * one Makefile is what answers for all of them: the project make is
 * run in is the only one that has every subproject's rules in hand,
 * and a subproject's object directory is as deletable as anybody's. */
static std::map<std::string, std::string>& configure_outputs_written(void)
{
    static std::map<std::string, std::string> written;
    return written;
}

bool file_utils::write_configure_output(const std::string& path,
                                        const std::string& contents)
{
    /* Only once it is there.  A file that could not be written is an
     * error for the caller to report, not a rule for the build to
     * carry. */
    if (write_if_changed(path, contents) == false)
        return false;

    configure_outputs_written()[path] = contents;
    return true;
}

const std::map<std::string, std::string>& file_utils::configure_outputs(void)
{
    return configure_outputs_written();
}

bool file_utils::inside(const std::string& path, const std::string& dir)
{
    if (path == dir)
        return true;

    return path.compare(0, dir.size() + 1, dir + "/") == 0;
}

std::string file_utils::real_directory(const std::string& path)
{
    auto resolved = ::realpath(path.c_str(), NULL);
    if (resolved == NULL)
        return "";

    auto out = std::string(resolved);
    free(resolved);
    return out;
}

std::set<std::string> file_utils::git_ignored_paths(const std::string& srcdir)
{
    std::set<std::string> out;

    /* "--directory" is what keeps this cheap for a tree with a
     * scratch directory full of its own output: without it, git
     * would list every file underneath one by one, and a caller
     * walking the tree would still have to recurse into the
     * directory to find them all.  With it, an entirely-ignored
     * directory is one entry ending in '/', which is stripped below
     * so it matches the directory path a walk is deciding whether to
     * recurse into. */
    auto cmd = "git -C " + string_utils::quoted(srcdir)
             + " ls-files --others --ignored --exclude-standard"
               " --directory -z 2>/dev/null";
    auto pipe = popen(cmd.c_str(), "r");
    if (pipe == NULL)
        return out;

    std::string buf;
    char chunk[4096];
    size_t n;
    while ((n = fread(chunk, 1, sizeof(chunk), pipe)) > 0)
        buf.append(chunk, n);
    pclose(pipe);

    size_t start = 0;
    while (start < buf.size()) {
        auto nul = buf.find('\0', start);
        if (nul == std::string::npos)
            nul = buf.size();

        auto entry = buf.substr(start, nul - start);
        if (entry.size() > 0 && entry.back() == '/')
            entry.pop_back();
        if (entry.size() > 0)
            out.insert(srcdir + "/" + entry);

        start = nul + 1;
    }

    return out;
}
