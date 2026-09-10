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

/* What a vendored tree read while it was working out its
 * configuration, turned into a piece of Makefile.
 *
 * pconfigure cannot know this.  A kbuild tree decides which Kconfig
 * files it reads by reading them, and the only honest way to find out
 * from the outside is to do the same -- which is what
 * kconfig_deps::chase() does, generously and approximately, at
 * configure time.
 *
 * But these trees write the answer down.  Both kbuild and buildroot
 * emit a Makefile fragment beside their configuration saying exactly
 * which files went into it, because their own builds need to know.
 * That file is written during the build rather than before it, so
 * reading it is a job for a program the build runs -- this one.
 *
 * The format is rigid in a way a Kconfig is not: one assignment, one
 * path per line, a backslash on the end.  That is the whole reason
 * this is worth doing.  Parsing it is fifteen lines; everything below
 * is deciding which of the paths mean anything from here.
 *
 * There are two of these answers, and a context file says which one
 * is being asked for.  A tree writes down what its CONFIGURATION read
 * in one file, beside the configuration.  What its BUILD read it
 * writes down a piece at a time, in a file beside each object it
 * compiled -- thousands of them, in the same format, which is why the
 * two halves are one program and not two. */

#include <libmakefile/path_prefix.h++>
#include <libpconfigure/context_file.h++>
#include <libpconfigure/file_utils.h++>
#include <fstream>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <algorithm>
#include <functional>
#include <iostream>
#include <set>
#include <unordered_set>
#include <string>
#include <vector>

namespace {
    void die(const std::string& message)
    {
        std::cerr << "psubdeps: " << message << "\n";
        exit(1);
    }

    class subdeps_context {
    public:
        /* Where this was read from, so the fragment can say. */
        std::string path;

        /* The vendored tree, named the way a Configfile named it.
         * Only ever printed. */
        std::string tree;

        /* Where that tree builds.  Anything the tree says it read
         * that lives in here is dropped -- see below. */
        std::string output;

        /* The rule these prerequisites get hung off, and the file
         * they get written to. */
        std::string target;
        std::string fragment;

        /* Where the tree writes its answer.  More than one, because
         * which name it goes by depends on the vendored tree's
         * vintage: the first one that exists wins, and none of them
         * existing is an ordinary state rather than an error. */
        std::vector<std::string> dep_files;

        /* What the paths in it are relative to. */
        std::string dep_root;

        /* Where the tree scatters what its build read, one file per
         * object.  Set instead of the two above, and what having it
         * set means is that this run is being asked the other
         * question.  A tree that writes nothing of the kind -- which
         * is every tree but a kbuild one -- simply never says it. */
        std::string cmd_root;

        /* Where make runs, spelled the way the vendored tree spells
         * it.  kbuild writes absolute paths, and this is the only
         * thing that can turn one back into a path this build can
         * use, or recognise it as naming somewhere else entirely. */
        std::string root;

        /* Only set for a project a parent can include. */
        std::string base;
        std::string variable;
        std::vector<std::pair<std::string, std::string>> peers;
    };

    subdeps_context read_context(const std::string& path)
    {
        auto out = subdeps_context();
        out.path = path;

        auto ok = context_file::read(path,
            [&](const std::string& key, const std::string& value) {
            if (key == "tree")            out.tree = value;
            else if (key == "output")     out.output = value;
            else if (key == "target")     out.target = value;
            else if (key == "fragment")   out.fragment = value;
            else if (key == "dep-file")   out.dep_files.push_back(value);
            else if (key == "dep-root")   out.dep_root = value;
            else if (key == "cmd-root")   out.cmd_root = value;
            else if (key == "root")       out.root = value;
            else if (key == "base")       out.base = value;
            else if (key == "variable")   out.variable = value;
            else if (key == "peer") {
                auto split = value.find(' ');
                if (split == std::string::npos)
                    die("a 'peer' needs a directory and a variable");
                out.peers.push_back(
                    std::make_pair(value.substr(0, split),
                                   value.substr(split + 1)));
            }
            /* Written by a pconfigure that knew about something this
             * one doesn't, which means the two disagree about what
             * the build is -- and guessing which half is right is how
             * a build ends up half configured. */
            else
                die("'" + key + "' in '" + path + "' means nothing here");
        });

        if (ok == false)
            die("unable to read the context file '" + path + "'");

        if (out.target.size() == 0)
            die("'" + path + "' says no 'target'");
        if (out.fragment.size() == 0)
            die("'" + path + "' says no 'fragment'");

        /* One question per context, because the two are answered out
         * of different files and land on different rules.  A context
         * that asks both, or neither, was written by something that
         * had not decided which -- and picking one here would make
         * half a Makefile out of it rather than saying so. */
        if (out.cmd_root.size() > 0 && out.dep_files.size() > 0)
            die("'" + path + "' asks for both a configuration and a"
                " build answer");
        if (out.cmd_root.size() == 0 && out.dep_files.size() == 0)
            die("'" + path + "' says neither 'dep-file' nor 'cmd-root'");
        if (out.cmd_root.size() > 0 && out.root.size() == 0)
            die("'" + path + "' says 'cmd-root' but no 'root'");

        return out;
    }

    /* The paths out of one of these files, which is the only parsing
     * here.
     *
     * The list opens with an assignment on a line of its own and runs
     * until either a line with no continuation on it or a blank one.
     * Both endings are needed rather than one: kbuild puts a
     * backslash on every entry including the last and ends the list
     * with a blank line, and buildroot's older writer leaves the
     * backslash off the last entry.  Everything else in the file --
     * the "autoconfig :=" above it, the "ifneq" guards and the
     * "$(deps_config): ;" below -- is somebody else's Makefile and is
     * none of this program's business. */
    std::vector<std::string> deps_config_of(const std::string& path)
    {
        auto out = std::vector<std::string>();

        auto file = std::ifstream(path);
        if (file.good() == false)
            return out;

        auto line = std::string();
        auto reading = false;
        while (std::getline(file, line)) {
            if (reading == false) {
                if (line == "deps_config := \\")
                    reading = true;
                continue;
            }

            if (line.size() == 0)
                break;
            if (line[0] != ' ' && line[0] != '\t')
                break;

            auto more = false;
            auto end = line.size();
            if (line[end - 1] == '\\') {
                more = true;
                end--;
            }

            while (end > 0 && (line[end - 1] == ' ' || line[end - 1] == '\t'))
                end--;

            auto start = std::string::size_type(0);
            while (start < end && (line[start] == ' ' || line[start] == '\t'))
                start++;

            if (end > start)
                out.push_back(line.substr(start, end - start));

            if (more == false)
                break;
        }

        return out;
    }

    /* Every file under a directory whose name ends in ".cmd", which
     * is where kbuild leaves what it learned while it was compiling.
     * There is one beside every object, so this is thousands of files
     * rather than one, and finding them is a walk rather than a name.
     *
     * A directory reached through a symlink is not followed.  A tree
     * that builds into a symlinked output would otherwise be walked
     * twice at best, and a link that points at one of its own parents
     * would not end at all. */
    void find_cmd_files(const std::string& dir, std::vector<std::string>& out)
    {
        auto handle = opendir(dir.c_str());
        if (handle == NULL)
            return;

        while (true) {
            auto entry = readdir(handle);
            if (entry == NULL)
                break;

            auto name = std::string(entry->d_name);
            if (name == "." || name == "..")
                continue;

            auto path = dir + "/" + name;

            struct stat info;
            if (lstat(path.c_str(), &info) != 0)
                continue;

            if (S_ISDIR(info.st_mode)) {
                find_cmd_files(path, out);
                continue;
            }

            if (name.size() > 4
                && name.compare(name.size() - 4, 4, ".cmd") == 0)
                out.push_back(path);
        }

        closedir(handle);
    }

    /* One of those files, whole.  These are read by the thousand and
     * a line at a time through a stream costs more than the scanning
     * below does, so the file arrives in one piece and gets walked
     * with two indices. */
    std::string read_file(const std::string& path)
    {
        auto file = std::ifstream(path, std::ios::binary);
        if (file.good() == false)
            return std::string();

        file.seekg(0, std::ios::end);
        auto size = file.tellg();
        if (size < 0)
            return std::string();
        file.seekg(0, std::ios::beg);

        auto out = std::string(static_cast<size_t>(size), '\0');
        file.read(&out[0], size);
        out.resize(static_cast<size_t>(file.gcount()));
        return out;
    }

    /* What one ".cmd" file says its object was built out of.
     *
     * Two assignments matter.  "source_" names the file that was
     * compiled, on one line.  "deps_" opens a list in exactly the
     * shape the configuration's own file uses, and is read the same
     * way.  Everything else in there is the command line that ran,
     * which is long, and none of this program's business.
     *
     * "deps_config" is skipped on purpose.  kbuild writes the
     * configuration's list in one of these files too, and it is the
     * one list here whose paths are relative to the source tree
     * rather than absolute -- so reading it here would be doing the
     * wrong arithmetic to an answer that is already being given
     * properly somewhere else. */
    void deps_build_of(const std::string& body,
                       const std::function<void(const std::string&)>& found)
    {
        auto at = std::string::size_type(0);
        auto reading = false;

        /* Walked by index rather than a line at a time, because a
         * kernel leaves nine million of these lines behind and most
         * of them are thrown away three characters in.  Cutting one
         * string per line out of that is the difference between this
         * being worth running after a build and not. */
        while (at < body.size()) {
            auto eol = body.find('\n', at);
            if (eol == std::string::npos)
                eol = body.size();

            auto begin = at;
            at = eol + 1;

            if (reading == true
                && (begin == eol
                    || (body[begin] != ' ' && body[begin] != '\t')))
                reading = false;

            if (reading == true) {
                auto more = false;
                auto stop = eol;
                if (body[stop - 1] == '\\') {
                    more = true;
                    stop--;
                }

                while (stop > begin && (body[stop - 1] == ' '
                                     || body[stop - 1] == '\t'))
                    stop--;

                while (begin < stop && (body[begin] == ' '
                                     || body[begin] == '\t'))
                    begin++;

                /* A config stamp the tree keeps for itself, written
                 * as a $(wildcard) because the tree allows it not to
                 * exist.  Recognised here, before it costs anything,
                 * because it is most of what is in these files. */
                if (stop > begin && body[begin] != '$')
                    found(body.substr(begin, stop - begin));

                if (more == false)
                    reading = false;

                continue;
            }

            auto length = eol - begin;

            if (length > 4
                && body.compare(begin, 5, "deps_") == 0
                && body.compare(begin, 12, "deps_config ") != 0
                && body.compare(eol - 4, 4, ":= \\") == 0) {
                reading = true;
                continue;
            }

            if (length > 7 && body.compare(begin, 7, "source_") == 0) {
                auto split = body.find(" := ", begin);
                if (split != std::string::npos && split + 4 < eol)
                    found(body.substr(split + 4, eol - split - 4));
            }
        }
    }

    /* What the tree's build read, as prerequisites of the stamp that
     * says the build has run.
     *
     * A tree that has never been built has scattered no such files,
     * and that is the state every clean checkout starts in.  It is
     * answered the same way the configuration's half answers it: with
     * a fragment that says nothing.  What the build stamp waits on
     * until then is the guess made while configuring, which is what
     * gets the first build to happen at all -- and the first build is
     * what replaces the guess with this. */
    int build_answer(const subdeps_context& ctx, makefile::path_prefix& prefix)
    {
        auto out = std::string();
        out += "# Written by psubdeps, from " + ctx.path + ".\n";
        out += "#\n";
        out += "# What the vendored tree in " + ctx.tree + " said it read"
               " while it was\n";
        out += "# building, the last time it was asked.  Editing this"
               " achieves nothing.\n\n";

        auto files = std::vector<std::string>();
        find_cmd_files(ctx.cmd_root, files);
        std::sort(files.begin(), files.end());

        if (files.size() == 0) {
            out += "# It has not been built yet, so it has not said"
                   " anything.  Building it\n";
            out += "# leaves one of these beside every object it"
                   " compiles, under\n";
            out += "#   " + ctx.cmd_root + "\n";
            out += "# and this file gets written again once that has"
                   " happened.\n";

            auto error = std::string();
            if (context_file::write(ctx.fragment, out, error) == false)
                die(error);
            return 0;
        }

        /* What an absolute path has to start with to be naming
         * something in this build at all.  Written with exactly one
         * slash on the end so that a root of "/a" cannot swallow a
         * path in "/ab". */
        auto root = ctx.root;
        while (root.size() > 0 && root[root.size() - 1] == '/')
            root.erase(root.size() - 1);
        root += "/";

        auto wanted = std::set<std::string>();
        auto dropped = std::set<std::string>();

        /* Every path here is named by nearly every object that was
         * compiled, so the four million entries a kernel writes are
         * some twelve thousand answers repeated.  Recognising a
         * repeat costs a hash; working out where it points costs a
         * path walked apart and put back together, and doing that
         * four million times is most of the time this program used
         * to take. */
        auto seen = std::unordered_set<std::string>();

        for (const auto& file: files) {
            deps_build_of(read_file(file), [&](const std::string& raw) {
                if (seen.insert(raw).second == false)
                    return;

                auto path = std::string();
                if (raw[0] == '/') {
                    /* Absolute and outside this build: a system
                     * header, belonging to something nothing here
                     * builds or installs. */
                    if (raw.compare(0, root.size(), root) != 0) {
                        dropped.insert(raw);
                        return;
                    }
                    path = raw.substr(root.size());
                } else {
                    /* Relative, which in one of these files means
                     * relative to where the tree builds -- so it is
                     * something the tree generated for itself. */
                    path = ctx.cmd_root + "/" + raw;
                }

                path = file_utils::normalize_path(path);

                /* Which is dropped on the same argument the
                 * configuration's half drops them on: a file this
                 * build writes is not a reason to run this build. */
                if (ctx.output.size() > 0
                    && path.compare(0, ctx.output.size(), ctx.output) == 0) {
                    dropped.insert(path);
                    return;
                }

                if (path.compare(0, 3, "../") == 0) {
                    dropped.insert(path);
                    return;
                }

                wanted.insert(prefix.rewrite(path));
            });
        }

        out += "# Read out of " + std::to_string(files.size())
             + " file(s) under " + ctx.cmd_root + ".\n\n";

        if (dropped.size() > 0)
            out += "# " + std::to_string(dropped.size()) + " path(s) it"
                   " named are not reachable from here, or are files it\n"
                   "# writes itself, and have been left out.\n\n";

        auto sorted = std::vector<std::string>(wanted.begin(), wanted.end());

        out += prefix.rewrite(ctx.target) + ": " + context_file::join(sorted)
             + "\n\n";

        /* For the same reason the configuration's half writes them:
         * a header that has gone away since the build read it is a
         * reason to build the tree again, not a reason for make to
         * refuse to build anything at all. */
        for (const auto& path: sorted)
            out += path + ":\n";

        auto error = std::string();
        if (context_file::write(ctx.fragment, out, error) == false)
            die(error);

        return 0;
    }
}

int main(int argc, const char **argv)
{
    auto context_path = std::string();

    for (auto i = 1; i < argc; ++i) {
        auto arg = std::string(argv[i]);

        if (arg == "--context" && i + 1 < argc) {
            context_path = argv[++i];
            continue;
        }

        die("unknown argument '" + arg + "'");
    }

    if (context_path.size() == 0)
        die("no --context given");

    auto ctx = read_context(context_path);

    auto prefix = ctx.base.size() == 0
        ? makefile::path_prefix()
        : makefile::path_prefix(ctx.base, ctx.variable, ctx.peers);

    if (ctx.cmd_root.size() > 0)
        return build_answer(ctx, prefix);

    auto out = std::string();
    out += "# Written by psubdeps, from " + ctx.path + ".\n";
    out += "#\n";
    out += "# What the vendored tree in " + ctx.tree + " said it read"
           " while it was\n";
    out += "# working out its configuration, the last time it was"
           " asked.  Editing\n";
    out += "# this achieves nothing.\n\n";

    /* Whichever of them the tree actually writes.  A tree that has
     * never been built has written none of them, and that is the
     * state every clean checkout starts in -- so it is answered with
     * a fragment that says nothing rather than with a failure.  The
     * build writes the file and asks again on its way past. */
    auto found = std::string();
    for (const auto& candidate: ctx.dep_files) {
        if (access(candidate.c_str(), R_OK) == 0) {
            found = candidate;
            break;
        }
    }

    if (found.size() == 0) {
        out += "# It has not been configured yet, so it has not said"
               " anything.  What\n";
        out += "# builds it will write one of:\n";
        for (const auto& candidate: ctx.dep_files)
            out += "#   " + candidate + "\n";
        out += "# and this file gets written again once that has"
               " happened.\n";

        auto error = std::string();
        if (context_file::write(ctx.fragment, out, error) == false)
            die(error);
        return 0;
    }

    out += "# Read out of " + found + ".\n\n";

    auto wanted = std::vector<std::string>();
    auto dropped = 0;
    for (const auto& raw: deps_config_of(found)) {
        /* An absolute path names nothing on anybody else's machine,
         * and every path pconfigure writes is relative to where make
         * runs.  Buildroot's list opens with a handful of them. */
        if (raw[0] == '/') {
            dropped++;
            continue;
        }

        auto path = file_utils::normalize_path(ctx.dep_root + raw);

        /* A file the tree's own build regenerates is a clock rather
         * than a dependency: buildroot rewrites its .br2-external.in.*
         * every time make is run, so a rule waiting on one is a rule
         * that is never up to date again.  Nothing under the output
         * directory is an input to configuring the tree. */
        if (ctx.output.size() > 0
            && path.compare(0, ctx.output.size(), ctx.output) == 0) {
            dropped++;
            continue;
        }

        /* And nothing above where make runs, for the same reason an
         * absolute path is no good. */
        if (path.compare(0, 3, "../") == 0) {
            dropped++;
            continue;
        }

        wanted.push_back(prefix.rewrite(path));
    }

    std::sort(wanted.begin(), wanted.end());
    wanted.erase(std::unique(wanted.begin(), wanted.end()), wanted.end());

    if (dropped > 0)
        out += "# " + std::to_string(dropped) + " path(s) it named are"
               " not reachable from here, or are files it\n"
               "# writes itself, and have been left out.\n\n";

    out += prefix.rewrite(ctx.target) + ": " + context_file::join(wanted)
         + "\n\n";

    /* One rule with nothing in it per path, so that a file which has
     * gone away since is a reason to configure the tree again rather
     * than a build that stops.  These are safe here in a way they
     * would not be on an included makefile: what they hang off is an
     * ordinary target, so make brings it up to date and moves on
     * instead of starting over and asking again. */
    for (const auto& path: wanted)
        out += path + ":\n";

    auto error = std::string();
    if (context_file::write(ctx.fragment, out, error) == false)
        die(error);

    return 0;
}
