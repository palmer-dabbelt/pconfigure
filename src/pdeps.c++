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
#include <libmakefile/recipe_quote.h++>
#include <libmakefile/target.h++>
#include <libpconfigure/command_processor.h++>
#include <libpconfigure/context_file.h++>
#include <libpconfigure/file_utils.h++>
#include <libpconfigure/languages/bash.h++>
#include <libpconfigure/languages/cxx.h++>
#include <cstdint>
#include <fstream>
#include <functional>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <iostream>
#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace {
    /* Said here so the context below can use it, and defined once,
     * down with the rest of the small things. */
    void die(const std::string& message);

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

        /* Where this program is, as a file name rather than a
         * command: it is a prerequisite of a fragment as well as the
         * thing a recipe runs, and make reads the two differently.
         * Quoted for the shell where a recipe runs it, and only
         * there. */
        std::string pdeps;

        /* What every recipe written below gets in front of it, which
         * is nothing at all for a build that was asked to say what it
         * is doing. */
        std::string at = "@";

        bool autodeps = true;

        /* The link steps this source's object belongs to, which is
         * the installed one and the local one. */
        std::vector<std::string> links;
        std::vector<std::string> opts;

        /* The files the build makes, each of which counts as being
         * where it will be when the scan goes looking for it.  A build
         * after "make clean" asks before any of them have been made
         * again, and a header this leaves out of the fragment is a
         * header the object is compiled without having waited for,
         * and is not recompiled for when it changes. */
        std::vector<std::string> made;

        /* The sources whose fragments the Makefile already knows how
         * to build, because a Configfile named them, and the fragment
         * each one's rule writes.  Writing a second rule for one of
         * those is two recipes for one file; and a named source is
         * built the way its own line says, which can be with options
         * of its own, so its fragment is not one this file's halves
         * can spell. */
        std::map<std::string, std::string> named;

        /* The context the sources found behind this one's headers
         * are described by, when nobody named them.  Those are built
         * with the target's options rather than this source's, so a
         * source with options of its own sends them somewhere else;
         * left empty, the walk stays in this file. */
        std::string behind;

        /* The context file to switch to for a source found behind a
         * header that another language compiles, by the ending that
         * says which.  A ".c++" behind a header a C program reads is
         * C++, and the compiler, options and object names that come
         * with that are in C++'s own one of these.  Asked of the
         * context "behind" names, since that is the one describing
         * the sources nobody named. */
        std::map<std::string, std::string> languages;

        std::string base, variable;
        std::vector<std::pair<std::string, std::string>> peers;

        /* Where this file was when it was written, spelled the way
         * every prefix above is spelled: from the top of the tree. */
        std::string self;

        /* Set for a script rather than a C source: "shell" or "perl",
         * which is how the compiler reads it and so how the walk for
         * what it includes has to.  A script is compiled into one
         * file with everything it includes pasted in, so there are no
         * objects and nothing behind the includes to build -- just
         * the file it turns into, which is "target". */
        std::string syntax;
        std::string target;

    public:
        std::string source_of(const std::string& name) const
            { return src_prefix + name; }
        std::string object_of(const std::string& name) const
            { return obj_prefix + name + obj_suffix; }
        std::string deps_of(const std::string& name) const
            { return dep_prefix + name + dep_suffix; }

        /* A subproject's Makefile is written to work both ways: a
         * parent includes it, and it can also be built where it sits.
         * The rules in it carry the directory as a variable that the
         * parent sets and the file defaults to nothing, so the same
         * rule names one path from the top of the tree and another
         * from inside the project -- and both are right, because make
         * is standing somewhere different in each case.
         *
         * Everything in this file is the first of those spellings,
         * frozen when pconfigure ran.  Read from inside the project
         * they have the project's own directory too many on the
         * front, which is not an error anything notices: the source
         * is looked for one directory too high and found missing, so
         * the answer written is that the source has been deleted.
         *
         * What must not be done about that is bring the paths down to
         * where make is standing.  A fragment is one file with two
         * readers -- the build from in here and the build from the
         * top -- and a path spelled from inside the subproject means
         * nothing to the second of them.  Rewriting the paths fixes
         * the build that is running and breaks the other one, which
         * is a worse bug than the one it fixes, because the fragment
         * it leaves behind outlives the build that wrote it.
         *
         * So the process moves rather than the paths.  Make has said
         * where it is standing by spelling the --context through that
         * variable, and the difference between that and the frozen
         * spelling is exactly the directories between here and the
         * top: walk up them, and every path in this file means what
         * it says again.  What gets written is then what a build from
         * the top would have written, down to the byte -- which is
         * the whole point, since that is who reads it next. */
        void stand_at_top(const std::string& live)
        {
            if (base.size() == 0 || self.size() == 0)
                return;
            if (self.compare(0, base.size(), base) != 0)
                return;

            auto tail = self.substr(base.size());
            if (live.size() < tail.size())
                return;
            if (live.compare(live.size() - tail.size(),
                             tail.size(), tail) != 0)
                return;

            auto live_base = live.substr(0, live.size() - tail.size());
            if (live_base == base)
                return;

            /* The two spellings have to describe one file seen from
             * two places, which means what make said is what
             * pconfigure said with some directories taken off the
             * front.  Anything else is a context file that does not
             * belong to this build, and walking up out of the tree
             * on the strength of it would be worse than stopping. */
            if (base.size() < live_base.size()
                || base.compare(base.size() - live_base.size(),
                                live_base.size(), live_base) != 0)
                die("'" + live + "' and '" + self + "' do not name the"
                    " same file from two places");

            /* What is left in front is the walk. */
            auto up = std::string();
            for (auto i = size_t(0); i < base.size() - live_base.size(); ++i)
                if (base[i] == '/')
                    up += up.size() == 0 ? ".." : "/..";

            if (up.size() == 0)
                return;

            if (chdir(up.c_str()) != 0)
                die("unable to reach the top of the tree, '" + up
                    + "' from here");

            /* Said from up here now, like everything else in this
             * file -- and unlike the argument, which is how make
             * spelled it from down there.  It is written out as a
             * prerequisite of every fragment below, so its spelling
             * matters as much as any other path's. */
            path = self;
        }
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

    /* The same arithmetic language_cxx hashes compile options into
     * an object's name with; what is hashed here is the list of
     * headers, which is this program's own answer. */
    std::string hash_of(const std::vector<std::string>& words)
    {
        std::hash<std::string> hash_fn;
        uint64_t seed = 5831;
        for (const auto& word: words)
            seed ^= hash_fn(word) + 0x9e3779b97f4a7c15ULL
                  + (seed << 6) + (seed >> 2);
        return std::to_string(seed);
    }

    deps_context read_context(const std::string& path)
    {
        auto out = deps_context();
        out.path = path;

        auto ok = context_file::read(path,
            [&](const std::string& key, const std::string& value) {
            if (key == "src-prefix")       out.src_prefix = value;
            else if (key == "obj-prefix")  out.obj_prefix = value;
            else if (key == "obj-suffix")  out.obj_suffix = value;
            else if (key == "dep-prefix")  out.dep_prefix = value;
            else if (key == "dep-suffix")  out.dep_suffix = value;
            else if (key == "compiler")    out.compiler = value;
            else if (key == "pretty")      out.pretty = value;
            else if (key == "pic")         out.pic = value;
            else if (key == "pdeps")       out.pdeps = value;
            else if (key == "quiet")       out.at = value == "true" ? "@" : "";
            else if (key == "base")        out.base = value;
            else if (key == "variable")    out.variable = value;
            else if (key == "self")        out.self = value;
            else if (key == "autodeps")    out.autodeps = value == "true";
            else if (key == "link")        out.links.push_back(value);
            else if (key == "behind")      out.behind = value;
            else if (key == "syntax")      out.syntax = value;
            else if (key == "target")      out.target = value;
            else if (key == "named") {
                /* A name on its own is what a pconfigure from before
                 * named sources carried their fragments wrote, and
                 * the walk below spells those fragments the way it
                 * always did.  The next configure rewrites this file
                 * in any case. */
                auto split = value.find(' ');
                if (split == std::string::npos)
                    out.named[value] = "";
                else
                    out.named[value.substr(0, split)] =
                        value.substr(split + 1);
            }
            else if (key == "opt")         out.opts.push_back(value);
            else if (key == "made")        out.made.push_back(value);
            else if (key == "behind-language") {
                auto split = value.find(' ');
                if (split == std::string::npos)
                    die("a 'behind-language' needs an ending and a"
                        " context file");
                out.languages[value.substr(0, split)] =
                    value.substr(split + 1);
            }
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

        return out;
    }

    /* The headers this source reads, which is the same question
     * language_cxx asks and is answered by the same function: the
     * include path and the defines come back out of the command line
     * it would have been compiled with. */
    std::vector<std::string> headers_of(const deps_context& ctx,
                                        const std::string& source,
                                        std::set<std::string>& missed)
    {
        return cxx_headers_read_by(source, ctx.opts, ctx.made,
            [&](const std::string& path) { missed.insert(path); });
    }

    /* The rule that runs this makes the directory too, since make
     * wants it made whether this program is what fills it or not.
     * Doing it here as well is what keeps a hand-run of this from
     * failing with a sentence about a file when the trouble is a
     * directory. */
    void write(const std::string& path, const std::string& body)
    {
        auto error = std::string();
        if (context_file::write(path, body, error) == false)
            die(error);
    }

    /* The last thing in a fragment that something links: a hash of
     * everything above it, said twice -- once as a comment, which is
     * what is on disk, and once as a make variable, which is what make
     * read.  The objects a link is made of are only ever said here,
     * so a link run while make holds an older reading of one of these
     * than the one on disk, or none at all, is a link of the wrong
     * list.  That is what happens when make remakes a fragment before
     * it has read it, and builds a link on the way to some makefile
     * that depends on it: the link rule compares the two and leaves
     * the link to the make that starts over.
     *
     * Hashed rather than stamped with when it was written, because
     * the rule that writes this again for a missing ".headers" stamp
     * can run with nothing having changed, and the same words on disk
     * as in make are a list make has right. */
    void seal(std::string& out,
              const std::string& deps,
              const makefile::path_prefix& prefix)
    {
        auto hash = hash_of(std::vector<std::string>{out});
        out += "# fragment " + hash + "\n";
        out += prefix.rewrite(guard("fragment", prefix.rewrite(deps))
                              + " := " + hash) + "\n";
    }

    std::string join(const std::vector<std::string>& v)
    {
        return context_file::join(v);
    }

    /* The places a file could turn up and be read instead of what the
     * scan found, and the rule that has this fragment written again
     * when one does.
     *
     * Every other prerequisite of a fragment is a file that is there,
     * and the fragment is rewritten when one of them changes.  A
     * header that shadows another -- a src/x.h beside the source
     * written after a build that found inc/x.h, or an inc1/x.h ahead
     * of an inc2/x.h -- changes what the source reads without
     * changing any of those, so a fragment that only watched them
     * went on naming the header that had been shadowed.  Without
     * AUTORECONFIGURE a reconfigure is what notices, because
     * pconfigure scans every source again whenever it runs; under it
     * the scan is this program's, and nothing ever asked it again,
     * not even an explicit pconfigure, until a "make clean".
     *
     * Whether one is there is asked rather than how new it is,
     * because a header brought in by "cp -p" or a tar extract has
     * whatever date it came with, and the one it shadows can be newer
     * than that.  A phony prerequisite is what makes the fragment
     * stale on the strength of a file being there at all.  Its being
     * there is also what stops it: the rewritten fragment found the
     * file where it was looked for and no longer lists it, so the
     * build asks once and then settles.  That is why pinclude leaves
     * off a place where something that is no header sits -- the
     * search would pass over it again and this would ask again, for
     * ever.
     *
     * The same check runs whether make was started by hand or by a
     * reconfigure, so a plain make notices too; there is no reason
     * for the build to know less than a reconfigure would tell it. */
    void watch_missed(const std::function<void(const std::string&)>& say,
                      const std::string& deps,
                      const std::set<std::string>& missed,
                      const makefile::path_prefix& prefix)
    {
        /* Only the names "$(wildcard)" reads as themselves.  One
         * with a glob character in it is a pattern there, and can
         * match a file the search would never have read -- which
         * would ask again after every rewrite, since the rewrite
         * still lists it.  A space or a make metacharacter splits or
         * expands the name before wildcard sees it.  A file turning
         * up at one of those is left for a "make clean" to notice, as
         * every one was before: a build that misses a rare name is
         * better than one that never stops for it. */
        auto watched = std::vector<std::string>();
        for (const auto& path: missed)
            if (path.find_first_of("*?[]\\ \t$%#:;=") == std::string::npos)
                watched.push_back(path);

        if (watched.size() == 0)
            return;

        auto g = guard("shadowed", prefix.rewrite(deps));
        say("ifneq ($(wildcard " + join(watched) + "),)");
        say(".PHONY: " + g);
        say(g + ":");
        say(deps + ": " + g);
        say("endif");
        say("");
    }

    /* What the scan found, spelled for a rule line.  Nobody chose
     * these names for a Makefile: a header called "my extra.h", or
     * "v$1.h", is what the "#include" said, and it goes onto the
     * object's line as the one file it is -- spelled the way
     * pconfigure spells the same header in its own Makefile.  Left
     * bare, a '$' in one named some other file, whose empty rule
     * below "remade" it on every pass, and make restarted for ever. */
    std::vector<std::string> prerequisites(const std::vector<std::string>& v)
    {
        auto out = std::vector<std::string>();
        for (const auto& path: v)
            out.push_back(makefile::prerequisite(path));
        return out;
    }

    /* The few names make has no spelling for at all, said here
     * rather than written into a fragment as a rule about some other
     * file.  "what" says how the source came to name the file. */
    void refuse_unspellable(const std::string& source,
                            const std::string& what,
                            const std::string& path)
    {
        auto why = makefile::unspellable(path);
        if (why.size() == 0)
            return;

        die("'" + source + "' " + what + " '" + path + "', which the"
            " Makefile cannot name: it is a prerequisite of what '"
            + source + "' is built into, and " + why + ".  Rename it --"
            " letters, digits, '-', '_', '.' and spaces are all safe --"
            " and include it by that name.");
    }

    /* The piece of Makefile for a script, which is the C one with
     * everything about objects taken out: what the script includes is
     * a prerequisite of the file it is compiled into, and of this
     * fragment, and that is all.  The reasoning for each of the pieces
     * that are left is the same as for C, and is written out over
     * their twins in main() below. */
    void write_script(const deps_context& ctx,
                      const makefile::path_prefix& prefix,
                      const std::string& name,
                      const std::string& header)
    {
        auto syntax = pinclude::syntax::SHELL;
        if (ctx.syntax == "perl")
            syntax = pinclude::syntax::PERL;
        else if (ctx.syntax != "shell")
            die("'" + ctx.syntax + "' in '" + ctx.path
                + "' is not a script syntax: it is 'shell' or 'perl'");

        if (ctx.target.size() == 0)
            die("'" + ctx.path + "' describes a script but names no"
                " target for it");

        auto source = ctx.source_of(name);
        auto deps = ctx.deps_of(name);

        auto out = header;
        auto say = [&](const std::string& line)
            { out += prefix.rewrite(line) + "\n"; };

        /* A script that has gone has nothing to say, and the rule for
         * the file it compiled into still names it, which is make's
         * business rather than this one's. */
        if (access(source.c_str(), R_OK) != 0) {
            out += "# There is no such file today, so it reads nothing.\n";
            write(deps, out);
            return;
        }

        auto missed = std::set<std::string>();
        auto includes = script_includes_read_by(source, ctx.opts, syntax,
            [&](const std::string& path) { missed.insert(path); });
        for (const auto& include: includes)
            refuse_unspellable(source, "includes", include);

        /* The list as a file, so that one which changes without any
         * file on it getting newer -- an include that now resolves to
         * another directory's copy, because the first was deleted --
         * still rebuilds the script. */
        auto stamp = deps + ".includes";
        auto had_stamp = access(stamp.c_str(), F_OK) == 0;
        {
            auto body = std::string();
            body += "# Written by pdeps, from " + ctx.path + "\n";
            body += "#\n";
            body += "# The files '" + source + "' includes, under the hash\n";
            body += "# the script is restaled on.  Editing it achieves\n";
            body += "# nothing.\n";
            body += "\n";
            body += hash_of(includes) + "\n";
            for (const auto& include: includes)
                body += include + "\n";

            if (file_utils::write_if_changed(stamp, body) == false)
                die("unable to write '" + stamp + "'");
        }

        /* A stamp that is new says the list is new, which is not the
         * same as saying it changed: there was no list before it to
         * have changed from.  Left at the time it was written, it is
         * newer than a script that was compiled before anyone asked
         * -- the first build of a tree whose bootstrap compiled its
         * own pconfigure, or the first after the object directory
         * was thrown away -- and that script is compiled again for
         * nothing.  When the script is a vendored pconfigure, that is
         * a reconfigure for nothing too.  So a first stamp is dated
         * like the newest of the files it lists, which is the one
         * thing the script being up to date can be checked against
         * without it.
         *
         * To the second, because that is the part of a file's time
         * every system spells the same way, and rounding down only
         * ever makes the stamp older than it might have been. */
        if (had_stamp == false) {
            auto newest = time_t(0);
            auto files = includes;
            files.push_back(source);
            for (const auto& file: files) {
                struct stat st;
                if (stat(file.c_str(), &st) == 0 && st.st_mtime > newest)
                    newest = st.st_mtime;
            }

            struct timespec times[2] = {{newest, 0}, {newest, 0}};
            if (utimensat(AT_FDCWD, stamp.c_str(), times, 0) != 0)
                die("unable to date '" + stamp + "'");
        }

        say(stamp + ":");
        out += "\t" + ctx.at + "test -f $@ || " + prefix.rewrite(
                   makefile::recipe_quoted(ctx.pdeps)
                   + " --context " + ctx.path
                   + " --source " + name) + "\n";
        out += "\n";

        auto target_deps = prerequisites(includes);
        target_deps.push_back(stamp);
        say(ctx.target + ": " + join(target_deps));
        say(deps + ": " + source + " " + join(prerequisites(includes)));
        out += "\n";

        watch_missed(say, deps, missed, prefix);

        /* An empty rule for each, so that a file the script has since
         * stopped including, and that has then been deleted, is
         * something make can remake rather than the end of the
         * build. */
        auto said = std::set<std::string>();
        said.insert(source);
        say(source + ":");
        for (const auto& include: includes)
            if (said.insert(include).second == true)
                say(makefile::rule_target(include) + ":");

        write(deps, out);
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
"same thing for every source sitting behind one of those headers.  For a\n"
"BASH or Perl script it is what the script includes, as a prerequisite of\n"
"the file the script is compiled into.\n"
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

    /* What make just said about where it is standing, which is the
     * only thing that can say so: every path in the context file is
     * spelled from the top of the tree and this one is spelled from
     * here.  Everything below runs at the top, whichever of the two
     * the build was started from. */
    ctx.stand_at_top(context_path);

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

    auto out = std::string();
    auto say = [&](const std::string& line)
        { out += prefix.rewrite(line) + "\n"; };

    out += "# Written by pdeps, from " + ctx.path + "\n";
    out += "#\n";
    out += "# What it says was true of '" + source + "' when make last"
           " asked, which\n";
    out += "# is what the rule rebuilding this file is for.  Editing"
           " it achieves\n";
    out += "# nothing.\n\n";

    if (ctx.syntax.size() > 0) {
        write_script(ctx, prefix, name, out);
        return 0;
    }

    /* A source that has been deleted since the last build still has a
     * fragment sitting in the object directory, and make reads that
     * before it reads the rewritten fragment of whatever used to pull
     * it in.  So this has to be answerable rather than fatal: what a
     * source that is not there contributes to the build is nothing,
     * and the fragment that used to name it will have stopped naming
     * it by the time make has finished starting over. */
    if (access(source.c_str(), R_OK) != 0) {
        out += "# There is no such file today, so it builds nothing"
               " and nothing\n";
        out += "# is linked against it.\n";
        seal(out, deps, prefix);
        write(deps, out);
        return 0;
    }

    auto missed = std::set<std::string>();
    auto headers = headers_of(ctx, source, missed);
    for (const auto& header: headers)
        refuse_unspellable(source, "reads the header", header);

    /* Read after the move to the top of the tree, because that is
     * where its path is spelled from. */
    auto behind = (ctx.behind.size() == 0 || ctx.behind == ctx.path)
        ? ctx
        : read_context(ctx.behind);

    /* The sources behind the headers, before this source's own
     * object, because that is the order pconfigure puts them in and
     * the order they are linked in has to come out the same either
     * way.
     *
     * The guard is the whole of the loop protection.  Two sources
     * that include each other's headers describe a circle, and an
     * "include" that went round it twice would be make reading
     * Makefiles until it ran out of memory. */
    /* The other languages' contexts, read the first time the walk
     * reaches one of their files.  Everything about the target in
     * them is what is in this one; what differs is how a source is
     * compiled and so what its object and fragment are called. */
    auto others = std::map<std::string, deps_context>();
    auto context_for = [&](const std::string& file) -> const deps_context&
        {
            for (const auto& entry: behind.languages) {
                auto& ending = entry.first;
                if (file.size() <= ending.size()
                    || file.compare(file.size() - ending.size(),
                                    ending.size(), ending) != 0)
                    continue;

                auto found = others.find(entry.second);
                if (found == others.end())
                    found = others.emplace(entry.second,
                                           read_context(entry.second)).first;
                return found->second;
            }
            return behind;
        };

    if (ctx.autodeps == true) {
        for (const auto& header: headers) {
            for (const auto& found: cxx_sources_for_header(header)) {
                if (found.compare(0, ctx.src_prefix.size(),
                                  ctx.src_prefix) != 0)
                    continue;

                auto sibling = found.substr(ctx.src_prefix.size());
                auto named = ctx.named.find(sibling);

                /* A source found here is built, so its name lands
                 * everywhere a SOURCES line's does -- on the left of
                 * rules, in an object's name, bare in a recipe -- and
                 * is held to what one of those is held to, the way
                 * language_cxx holds it when it does this walk itself.
                 * The header in front of it is spelled for make and
                 * is fine; this is not. */
                for (const auto& c: sibling) {
                    auto why = make_special_character(c);
                    if (why.size() == 0)
                        continue;

                    auto shown = c == '\n' ? std::string("\\n")
                               : c == '\t' ? std::string("\\t")
                               : std::string(1, c);
                    die("'" + source + "' reads '" + header + "', and"
                        " the source behind it, '" + found + "', has a"
                        " '" + shown + "' in its name: it is built into"
                        " this target, which makes it the name of"
                        " something the Makefile builds, and " + why
                        + ".  Rename the source without it, and the"
                        " header beside it to match, or set AUTODEPS ="
                        " false on the target if it was never meant to"
                        " be built into it.");
                }

                /* What the sibling is compiled as is a matter of its
                 * own name rather than this source's, so the fragment
                 * describing a source nobody named is named, built and
                 * rebuilt from the context of whichever language that
                 * is. */
                auto& owner = context_for(found);
                auto sibling_deps =
                    (named != ctx.named.end() && named->second.size() > 0)
                    ? named->second
                    : owner.deps_of(sibling);
                auto g = guard("deps", prefix.rewrite(sibling_deps));

                say("ifndef " + g);
                say(g + " := 1");

                if (named == ctx.named.end()) {
                    /* "$(wildcard)" rather than the path, because
                     * the path may stop existing.  A source can be
                     * deleted without anything that reads it
                     * changing -- what pulled it in was a header,
                     * and the header is still there -- so this
                     * fragment goes on naming it after it is gone,
                     * and make reads this fragment before it reads
                     * whatever has since stopped naming it.
                     *
                     * Naming a file that is not there is a build
                     * that stops on "No rule to make target".
                     * Giving it a rule with nothing in it is worse:
                     * make would decide this fragment needs
                     * remaking, remake it, start over, decide again,
                     * and never stop.  Asking whether the file
                     * exists has neither problem, and when the file
                     * comes back it is a prerequisite again. */

                    /* And pdeps, for the reason the rules pconfigure
                     * writes name it too: a fragment is what one
                     * version of pdeps made of a source, so a pdeps
                     * that has learned to see something new has to be
                     * able to say so.  This half is not the same half
                     * -- pconfigure never writes a rule for a source
                     * it was never told about, so without this line
                     * every fragment reached through a header would
                     * go on saying whatever the old pdeps thought,
                     * for as long as the header and the source both
                     * sat still.
                     *
                     * The path is the one out of the context file,
                     * which is the absolute path pconfigure resolved
                     * pdeps to.  That matters: a tree that vendors
                     * pconfigure has a rule for that binary under a
                     * relative spelling, make does not treat the two
                     * spellings as one file, and an absolute path
                     * with no rule behind it is a timestamp and
                     * nothing else -- which is all that is wanted,
                     * and the only spelling that does not drag a link
                     * of pconfigure into the phase where make is
                     * still working out what to include.  "$(wildcard)"
                     * around it because "make clean" takes that
                     * binary away, and a build after a clean must go
                     * back to having no opinion rather than stopping.
                     *
                     * Only when there is one to name.  pdeps can be
                     * run with a context written by a pconfigure that
                     * could not work out where it was standing, and
                     * "$(wildcard )" with nothing in it is a wart in
                     * every fragment in the tree for no gain. */
                    auto by = behind.pdeps.size() == 0
                        ? std::string()
                        : " $(wildcard " + behind.pdeps + ")";

                    say(sibling_deps + ": $(wildcard " + found + ") "
                        + owner.path + by);
                    out += "\t" + behind.at + "echo \"DEPS\t" + sibling
                           + "\"\n";
                    out += "\t" + behind.at + "mkdir -p $(dir $@)\n";
                    out += "\t" + behind.at + prefix.rewrite(
                               makefile::recipe_quoted(behind.pdeps)
                               + " --context " + owner.path
                               + " --source " + sibling) + "\n";

                    /* And "make clean" takes it, the way it takes the
                     * fragments pconfigure named -- which have a rule
                     * of their own, and a clean rule of their own
                     * along with it.  That is why this is in here
                     * rather than beside the include: writing a
                     * second clean rule for a fragment the Makefile
                     * already cleans is two recipes for one name. */
                    auto c = guard("clean", prefix.rewrite(sibling_deps));
                    say(".PHONY: " + c);
                    say(c + ":; @rm -fr " + sibling_deps);
                    say("clean: " + c);
                }

                /* What is linked out of the source behind the
                 * header is said in its own fragment, so each link
                 * waits for that to be written before it asks
                 * whether what make read of it is still what it
                 * says. */
                for (const auto& link: ctx.links)
                    say(link + ": | " + sibling_deps);

                /* Said by every include, for the reason
                 * makefile::note_if_unread() gives: a link the
                 * sibling goes into is not whole until make has
                 * read this. */
                auto note = makefile::note_if_unread(sibling_deps);
                note.pop_back();
                say(note);
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

    /* The headers as a file, because a list is the one thing make
     * cannot see change.  The object's line below names every header
     * this source read the last time pdeps was asked, and a header it
     * can no longer resolve comes back off that list: the re-derived
     * fragment does not say the header went away, it says nothing at
     * all, and a name that is not there is a name make has never
     * heard of.  The build believes whatever it believed before,
     * which is how a binary goes on carrying the contents of a file
     * that is no longer in the tree.
     *
     * So the list is hashed into a stamp beside the object, and
     * the object reads the stamp as a prerequisite.  The hash changes
     * exactly when the list does, the stamp moves exactly once, and
     * the object is remade against the include graph that is actually
     * on disk.
     *
     * Written through write_if_changed(), the way pconfigure writes
     * the context this run read: a stamp rewritten by every run is a
     * prerequisite that moves every run, and an object behind one of
     * those is a build that never settles.  Nothing here is allowed
     * to be new except the answer.
     *
     * The stamp takes a rule too, and one with nothing to run while
     * the file is there: make fires a rule with no prerequisites only
     * for a target that does not exist.  That is what stands between
     * a stamp that has gone missing and a build that stops on a file
     * nothing has a rule for, and it is also why the rule cannot be
     * the empty kind the headers below get -- make's opinion of a
     * file it remade and could not find is that the file changed, and
     * an object behind a permanently missing stamp is a build that
     * never stops rebuilding.  Running pdeps writes the stamp back,
     * and the object chases it once.  The rule also makes the stamp a
     * target, which is what "make cache-clean" reads to decide what
     * the build still knows how to make: named only as a
     * prerequisite, the stamp would be thrown away out from under the
     * line that names it, and the next build would stop on it.
     *
     * "make clean" leaves the stamp where it is, the way it leaves
     * the context files: its rules take fragments and objects by
     * name, and a stamp whose content still describes the headers
     * says nothing new.  The object it belongs to is coming back
     * regardless.
     *
     * The stamp is the object's rather than this fragment's, and sits
     * beside the object under its name.  Two targets that compile a
     * source the same way share the object and each get a fragment of
     * their own, and a stamp per fragment was a stamp born with every
     * new consumer: adding a second program built from a source the
     * first already used wrote that program's stamp after the object,
     * and the object -- with every link already using it -- was
     * rebuilt for a list of headers it had been compiled against all
     * along.  The list is a property of the compile, which every
     * fragment of this object describes identically, so they all
     * share one stamp and the first of them to be read gives it its
     * rule.  For the same reason the body names the source and not
     * the context it was asked through: a stamp that said which
     * fragment wrote it last would change with whoever got there
     * first, and move the object every time they took turns. */
    auto stamp = object + ".headers";
    {
        auto body = std::string();
        body += "# Written by pdeps\n";
        body += "#\n";
        body += "# The headers '" + source + "' reads, under the hash\n";
        body += "# the object is restaled on.  Editing it achieves\n";
        body += "# nothing.\n";
        body += "\n";
        body += hash_of(headers) + "\n";
        for (const auto& header: headers)
            body += header + "\n";

        if (file_utils::write_if_changed(stamp, body) == false)
            die("unable to write '" + stamp + "'");
    }

    {
        auto g = guard("stamp", prefix.rewrite(stamp));

        say("ifndef " + g);
        say(g + " := 1");
        say(stamp + ":");
        out += "\t" + ctx.at + "test -f $@ || " + prefix.rewrite(
                   makefile::recipe_quoted(ctx.pdeps)
                   + " --context " + ctx.path
                   + " --source " + name) + "\n";
        say("endif");
    }
    out += "\n";

    auto object_deps = std::vector<std::string>{source};
    for (const auto& header: prerequisites(headers))
        object_deps.push_back(header);
    object_deps.push_back(stamp);

    say(object + ": " + join(object_deps));
    say(deps + ": " + source + " " + join(prerequisites(headers)));
    out += "\n";

    watch_missed(say, deps, missed, prefix);

    /* A header that has been deleted is a prerequisite make has no
     * rule for, and make stops rather than building anything.  But a
     * header going away is one of the ordinary things that happens to
     * a source tree, and the build has to stay answerable rather than
     * fatal: a rule with nothing in it gives make something to run
     * instead of an error -- and, having no recipe, nothing that
     * changes the world while it runs.
     *
     * What it does not do is get the object rebuilt.  The deletion
     * does restale the fragment -- a prerequisite make remade without
     * finding it afterwards is one it treats as changed -- and
     * remaking the fragment is what runs pdeps again, which is how
     * the re-derived copy above stops naming the header.  But
     * remaking a file make has included also sends it back to the
     * top, and the graph it reads on the way back through no longer
     * mentions the deletion anywhere: every trace of the header is in
     * the file that was just replaced.  The object therefore starts
     * over up to date, which is what the stamp above is for. */
    {
        auto said = std::set<std::string>();

        /* The source gets one too, and for the same reason: a source
         * that has gone away leaves this fragment behind, and make
         * reads it before it reads the one that has stopped naming
         * it. */
        said.insert(source);
        say(source + ":");

        for (const auto& header: headers)
            if (said.insert(header).second == true)
                say(makefile::rule_target(header) + ":");
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
        auto c = guard("clean", prefix.rewrite(object));
        say(".PHONY: " + c);
        say(c + ":; @rm -fr " + object);
        say("clean: " + c);
        say(object + ":");
        out += "\t" + ctx.at + "echo \"" + ctx.pretty + "\t" + name + "\"\n";
        out += "\t" + ctx.at + "mkdir -p $(dir $@)\n";
        out += "\t" + ctx.at + prefix.rewrite(
                   ctx.compiler + " " + join(ctx.opts)
                   + " -c " + source + " -o " + object
                   + (ctx.pic.size() > 0 ? " " + ctx.pic : "")) + "\n";
        say("endif");
    }
    out += "\n";

    seal(out, deps, prefix);
    write(deps, out);
    return 0;
}
