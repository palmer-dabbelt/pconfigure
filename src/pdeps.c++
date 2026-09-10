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

/* Works out what one source file depends on, and writes it down as a
 * piece of Makefile.
 *
 * This is the half of pconfigure that has to be able to run again
 * without running all of it.  Which headers a source reads is a
 * question about a file on disk, and the answer stops being true the
 * moment somebody edits an "#include" -- so under AUTORECONFIGURE it
 * is asked by make, of one source at a time, rather than by
 * pconfigure, of every source at once.
 *
 * There is deliberately no recursion in here.  A source that pulls in
 * a header with a source of its own needs that source built and
 * linked too, and what this writes for that is an "include" of the
 * piece of Makefile describing it -- which make will build, by
 * running this again, before it reads it.  The walk is the same walk
 * pconfigure does; make is what is doing the walking.
 *
 * Everything about the target being built -- where its objects go,
 * what it compiles with, what gets linked -- arrives in the context
 * file, which pconfigure wrote when it ran.  None of it is worked out
 * here, because a second implementation of any of it is a second
 * answer waiting to disagree with the first. */

#include <libmakefile/path_prefix.h++>
#include <libpconfigure/file_utils.h++>
#include <libpconfigure/languages/cxx.h++>
#include <pinclude.h++>
#include <fstream>
#include <iostream>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace {
    /* Everything pconfigure knew about the target this source is
     * being compiled into, read back out of the file it left. */
    class deps_context {
    public:
        /* Where the file itself is, which the rules written below
         * name as a prerequisite: a source whose options changed is a
         * source whose dependencies have to be worked out again. */
        std::string path;

        /* A source name, an object and a piece of Makefile are the
         * same name with something on either side of it.  Keeping the
         * halves rather than the rule for putting them together is
         * what lets a name this program was never told about -- one
         * it found behind a header -- be spelled the same way
         * pconfigure would have spelled it. */
        std::string src_prefix;
        std::string obj_prefix, obj_suffix;
        std::string dep_prefix, dep_suffix;

        std::string compiler, pretty, pic;
        std::string pdeps;
        std::string at;

        bool autodeps = true;

        /* The link steps this source's object belongs to, which is
         * the installed one and the local one. */
        std::vector<std::string> links;
        std::vector<std::string> opts;

        std::string base, variable;
        std::vector<std::pair<std::string, std::string>> peers;

    public:
        std::string source_of(const std::string& name) const
            { return src_prefix + name; }
        std::string object_of(const std::string& name) const
            { return obj_prefix + name + obj_suffix; }
        std::string deps_of(const std::string& name) const
            { return dep_prefix + name + dep_suffix; }
    };

    void die(const std::string& message)
    {
        std::cerr << "pdeps: " << message << "\n";
        abort();
    }

    /* A make variable standing in for "this has already been said".
     * The name of the thing is the name of the variable, which is the
     * only spelling that can't collide with another one. */
    std::string guard(const std::string& kind, const std::string& name)
    {
        return "__pconfigure__" + kind + "-" + name;
    }

    deps_context read_context(const std::string& path)
    {
        auto file = std::ifstream(path);
        if (file.good() == false)
            die("unable to read the context file '" + path + "'");

        auto out = deps_context();
        out.path = path;

        auto line = std::string();
        while (std::getline(file, line)) {
            if (line.size() == 0)
                continue;

            auto space = line.find(' ');
            auto key = line.substr(0, space);
            auto value = space == std::string::npos
                ? std::string()
                : line.substr(space + 1);

            if (key == "src-prefix")       out.src_prefix = value;
            else if (key == "obj-prefix")  out.obj_prefix = value;
            else if (key == "obj-suffix")  out.obj_suffix = value;
            else if (key == "dep-prefix")  out.dep_prefix = value;
            else if (key == "dep-suffix")  out.dep_suffix = value;
            else if (key == "compiler")    out.compiler = value;
            else if (key == "pretty")      out.pretty = value;
            else if (key == "pic")         out.pic = value;
            else if (key == "pdeps")       out.pdeps = value;
            else if (key == "at")          out.at = value;
            else if (key == "base")        out.base = value;
            else if (key == "variable")    out.variable = value;
            else if (key == "autodeps")    out.autodeps = value == "true";
            else if (key == "link")        out.links.push_back(value);
            else if (key == "opt")         out.opts.push_back(value);
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
        }

        return out;
    }

    /* The headers this source reads, which is the same question
     * language_cxx asks and asked the same way: the include path and
     * the defines come back out of the command line it would have
     * been compiled with. */
    std::vector<std::string> headers_of(const deps_context& ctx,
                                        const std::string& source)
    {
        auto defined = std::vector<std::string>();
        auto include_dirs = std::vector<std::string>();

        for (const auto& opt: ctx.opts) {
            if (opt.compare(0, 2, "-D") == 0)
                defined.push_back(opt.substr(2));
            if (opt.compare(0, 2, "-I") == 0)
                include_dirs.push_back(opt.substr(2));
        }

        auto out = std::vector<std::string>();
        pinclude::list(source,
                       include_dirs,
                       defined,
                       [&](std::string s) {
                           out.push_back(s);
                           return 0;
                       },
                       true);
        return out;
    }

    std::string join(const std::vector<std::string>& v)
    {
        auto out = std::string();
        for (const auto& e: v) {
            if (out.size() > 0)
                out += " ";
            out += e;
        }
        return out;
    }
}

int main(int argc, const char **argv)
{
    auto context_path = std::string();
    auto name = std::string();

    for (auto i = 1; i < argc; ++i) {
        auto arg = std::string(argv[i]);

        if (arg == "--help" || arg == "-h") {
            std::cout <<
"usage: pdeps --context FILE --source NAME\n"
"\n"
"pdeps writes the piece of Makefile that says what one source file depends\n"
"on: the headers it reads, the rule that compiles it, and an include of the\n"
"same thing for every source sitting behind one of those headers.\n"
"\n"
"It is run by the Makefiles pconfigure writes for a project that asked for\n"
"AUTORECONFIGURE, and the context file is what pconfigure left behind to\n"
"say which target is being built.  There is nothing here to run by hand.\n";
            return 0;
        }

        if (arg == "--context" || arg == "--source") {
            if (i + 1 >= argc) {
                std::cerr << "pdeps: '" << arg
                          << "' needs an argument after it\n";
                return 1;
            }

            if (arg == "--context")
                context_path = argv[i + 1];
            else
                name = argv[i + 1];

            ++i;
            continue;
        }

        std::cerr << "pdeps: unknown argument '" << arg << "'\n";
        return 1;
    }

    if (context_path.size() == 0 || name.size() == 0) {
        std::cerr << "pdeps: both --context and --source are needed\n";
        return 1;
    }

    auto ctx = read_context(context_path);

    /* Every path written below is worked out from where pconfigure
     * ran and spelled through whichever project it belongs to, which
     * is what pconfigure does to its own Makefile and for the same
     * reason: this file gets included by one. */
    auto prefix = ctx.base.size() == 0
        ? makefile::path_prefix()
        : makefile::path_prefix(ctx.base, ctx.variable, ctx.peers);

    auto source = ctx.source_of(name);
    auto object = ctx.object_of(name);
    auto deps = ctx.deps_of(name);

    auto headers = headers_of(ctx, source);

    auto out = std::string();
    auto say = [&](const std::string& line)
        { out += prefix.rewrite(line) + "\n"; };

    out += "# Written by pdeps, from " + context_path + "\n";
    out += "#\n";
    out += "# What it says was true of '" + source + "' when make last"
           " asked, which\n";
    out += "# is what the rule rebuilding this file is for.  Editing"
           " it achieves\n";
    out += "# nothing.\n\n";

    /* The sources behind the headers, before this source's own
     * object, because that is the order pconfigure puts them in and
     * the order they are linked in has to come out the same either
     * way.
     *
     * The guard is the whole of the loop protection.  Two sources
     * that include each other's headers describe a circle, and an
     * "include" that went round it twice would be make reading
     * Makefiles until it ran out of memory. */
    if (ctx.autodeps == true) {
        for (const auto& header: headers) {
            for (const auto& behind: cxx_sources_for_header(header)) {
                if (behind.compare(0, ctx.src_prefix.size(),
                                   ctx.src_prefix) != 0)
                    continue;

                auto sibling = behind.substr(ctx.src_prefix.size());
                auto sibling_deps = ctx.deps_of(sibling);
                auto g = guard("deps", prefix.rewrite(sibling_deps));

                say("ifndef " + g);
                say(g + " := 1");
                say(sibling_deps + ": " + behind + " " + ctx.path);
                out += "\t" + ctx.at + "echo \"DEPS\t" + sibling + "\"\n";
                out += "\t" + ctx.at + "mkdir -p $(dir $@)\n";
                out += "\t" + ctx.at + prefix.rewrite(
                           ctx.pdeps + " --context " + ctx.path
                           + " --source " + sibling) + "\n";
                say("include " + sibling_deps);
                say("endif");
                out += "\n";
            }
        }
    }

    /* What this source contributes to the thing being built, which is
     * one object on a link line. */
    for (const auto& link: ctx.links)
        say(link + ": " + object);
    out += "\n";

    say(object + ": " + source + " " + join(headers));
    say(deps + ": " + source + " " + join(headers));
    out += "\n";

    /* A header that has been deleted is a prerequisite make has no
     * rule for, and make stops rather than building anything.  But a
     * header going away is one of the ordinary things that happens to
     * a source tree, and what should follow is a rebuild -- which is
     * what a rule with nothing in it gets: the prerequisite stops
     * being an error, and the file being missing is still older than
     * everything, so whatever read it is built again. */
    {
        auto said = std::set<std::string>();
        for (const auto& header: headers)
            if (said.insert(header).second == true)
                say(header + ":");
    }
    out += "\n";

    /* Two targets built from the same sources with the same options
     * share their objects, and the two of them describing one rule
     * would be make quietly picking a description.  Which one it
     * picked would not matter -- the options are hashed into the
     * name, so a shared object is a shared recipe -- but "quietly" is
     * the part worth avoiding. */
    {
        auto g = guard("object", prefix.rewrite(object));

        say("ifndef " + g);
        say(g + " := 1");
        say(".PHONY: " + guard("clean", object));
        say(guard("clean", object) + ":; @rm -fr " + object);
        say("clean: " + guard("clean", object));
        say(object + ":");
        out += "\t" + ctx.at + "echo \"" + ctx.pretty + "\t" + name + "\"\n";
        out += "\t" + ctx.at + "mkdir -p $(dir $@)\n";
        out += "\t" + ctx.at + prefix.rewrite(
                   ctx.compiler + " " + join(ctx.opts)
                   + " -c " + source + " -o " + object + ctx.pic) + "\n";
        say("endif");
    }

    /* The rule that runs this makes the directory too, since make
     * wants it made whether this program is what fills it or not.
     * Doing it here as well is what keeps a hand-run of this from
     * failing with a sentence about a file when the trouble is a
     * directory. */
    {
        auto slash = deps.find_last_of('/');
        if (slash != std::string::npos)
            if (file_utils::mkdir_p(deps.substr(0, slash)) == false)
                die("unable to create '" + deps.substr(0, slash) + "'");
    }

    auto file = std::ofstream(deps);
    if (file.good() == false)
        die("unable to write '" + deps + "'");
    file << out;

    return 0;
}
