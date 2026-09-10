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
 * is deciding which of the paths mean anything from here. */

#include <libmakefile/path_prefix.h++>
#include <libpconfigure/context_file.h++>
#include <libpconfigure/file_utils.h++>
#include <fstream>
#include <unistd.h>
#include <algorithm>
#include <iostream>
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
