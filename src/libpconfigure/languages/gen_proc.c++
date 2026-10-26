/*
 * Copyright (C) 2015-2016 Palmer Dabbelt
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

#include "gen_proc.h++"
#include "../language_list.h++"
#include "../file_utils.h++"
#include "../project.h++"
#include <assert.h>
#include <glob.h>
#include <set>
#include <unistd.h>
#include <iostream>

/* Where a GENERATE's output is written before it is moved into place,
 * where its dependency fragment lives, and where the recipe that made
 * the fragment is recorded.  The recipes spell the fragment's own
 * leftovers as "$@.raw" and "$@.tmp", so those two are named off the
 * fragment rather than off the output.  The recipe that made the output
 * itself is recorded where every other output's is, by
 * recipe_record_path(). */
static std::string temporary_path(const std::string& output)
{
    return output + ".tmp";
}

static std::string fragment_path(const std::string& output)
{
    return output + ".d";
}

static std::string fragment_context_path(const std::string& output)
{
    return output + ".d-context";
}

std::vector<std::pair<std::string, std::string>>
language_gen_proc::scratch_files(const context::ptr& ctx,
                                 const std::string& output)
{
    auto fragment = fragment_path(output);
    return {
        {temporary_path(output), "the temporary"},
        {recipe_record_path(ctx, output),
         "the record of the recipe that writes the output"},
        {fragment, "the dependency fragment"},
        {fragment + ".raw", "the dependency fragment's raw --deps answer"},
        {fragment + ".tmp", "the dependency fragment's temporary"},
        {fragment_context_path(output),
         "the record of the dependency fragment's recipe"},
    };
}

language_gen_proc* language_gen_proc::clone(void) const
{
    return new language_gen_proc(this->list_compile_opts(),
                                 this->list_link_opts());
}

bool language_gen_proc::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::BINARY:
    case context_type::LIBRARY:
    case context_type::SOURCE:
    case context_type::TEST:
    case context_type::HEADER:
    case context_type::PHONY:
        return false;

    case context_type::GENERATE:
        return language::all_sources_match(ctx, {".proc"});
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

std::vector<makefile::target::ptr>
language_gen_proc::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::BINARY:
    case context_type::LIBRARY:
    case context_type::SOURCE:
    case context_type::TEST:
    case context_type::HEADER:
    case context_type::PHONY:
        std::cerr << "Unimplemented context type: "
                  << std::to_string(ctx->type)
                  << "\n";
        std::cerr << ctx->as_tree_string("  ");
        abort();
        break;

    case context_type::GENERATE:
    {
        auto target = ctx->gen_dir + "/" + ctx->cmd->data();
        auto procfile = ctx->src_dir + "/" + ctx->cmd->data() + ".proc";

        /* The script gets run from the top of the project it belongs
         * to, not from wherever pconfigure happens to be running, so
         * that the paths it reads and the paths it prints are the
         * ones it was written against.  For a project that nothing
         * pulled in those are the same place.
         *
         * The '.' on the end is what keeps the trailing '/', which is
         * the only spelling of a directory that the rewriting on the
         * way into a Makefile recognizes as a path -- and this
         * recipe has to say "the project" rather than "sub" for the
         * same reason every other line in that file does.  It reads
         * as "sub/." from a parent and as "." from inside the
         * project, and both of those are the directory meant. */
        auto in_project = [&](const std::string& command) {
            if (ctx->base.size() == 0)
                return command;
            return "cd " + ctx->base + "." + " && " + command;
        };

        /* A line of the --deps answer whose first character is a '?'
         * names an OPTIONAL input: something the script reads when it
         * is there and does without when it is not.  The '?' is not
         * part of the path, and the path it marks is recorded wrapped
         * in a filter rather than named outright -- in both of the
         * places prerequisites get written down, here and in the
         * re-derived fragment further down, because a line that
         * reached either one bare would undo the other.
         *
         * What wanted this: glade-vm's fixture scripts look for an
         * AArch64 cross compiler that buildroot builds later on in the
         * same tree, and deliberately printed nothing whatsoever about
         * it, because naming it would have broken every build that did
         * not have one yet.  So the generated fixture encoded a
         * verdict about the toolchain while the dependency graph held
         * nothing about the toolchain -- a cache with no key.  The
         * empty fixture minted at configure time, before buildroot
         * existed, stayed "up to date" straight across the build of
         * the compiler that would have filled it, and 472 of 479 tests
         * skipped for three days while the suite scored every skip as
         * a pass. */
        auto optional_dep = [](const std::string& line) {
            return line.size() > 0 && line[0] == '?';
        };

        /* The path an optional line names: whatever follows the '?',
         * with leading whitespace dropped.  The '?' marks the line, so
         * anything between it and the path is a separator rather than
         * part of the path -- and dropping it is also what collapses
         * "? " and "?" into the one thing the guard below has to
         * refuse, rather than leaving two near-misses of which the
         * guard catches one.  Trailing whitespace is left where it is:
         * measured, GNU make 4.4.1 answers "$(wildcard real.txt )"
         * and "$(wildcard real.txt)" alike, so trimming it would buy
         * nothing and would need a '$' anchor in the sed below that
         * the delimiter there makes awkward. */
        auto optional_path = [](const std::string& line) {
            auto rest = line.substr(1);
            auto start = rest.find_first_not_of(" \t");
            return start == std::string::npos
                ? std::string() : rest.substr(start);
        };

        /* The paths a --deps line names, spelled the way the Makefile
         * spells them: relative to where pconfigure ran, with the
         * owning project on the front, and with the optional marker
         * off.  Everything downstream of here wants the paths rather
         * than the line, and the marker left on one of them is a
         * prerequisite named "?src/thing" that nothing will ever
         * build.
         *
         * PATHS, and rooted one at a time, because a line is not a
         * path.  At the top of a tree the line goes into a
         * prerequisite list as written, and make reads whitespace there
         * as a separator: "  src/a" is src/a, "src/a src/b" is two
         * inputs, a blank line is nothing, and "/opt/x" is /opt/x.  A
         * subproject used to paste its prefix onto the front of the
         * line instead, so each of those meant something else one
         * level down -- "sub/" and a top-level src/a, a second path
         * left naming a file in the parent, a blank line that hung the
         * output off the subproject's own directory, and "sub//opt/x",
         * which is no file at all.  Splitting the line into words and
         * rooting each one is what makes a script mean the same thing
         * wherever its project sits.  An absolute path is rooted
         * already and is left alone: it names one file whoever reads
         * it, and that is the reason a script spells it that way. */
        auto root_path = [&](const std::string& path) {
            return path[0] == '/' ? path : ctx->base + path;
        };
        auto dep_paths = [&](const std::string& line) {
            auto text = optional_dep(line) == true
                ? optional_path(line) : line;
            auto out = std::vector<std::string>();
            auto end = std::string::size_type(0);
            while (true) {
                auto start = text.find_first_not_of(" \t\v\f\r", end);
                if (start == std::string::npos)
                    break;
                end = text.find_first_of(" \t\v\f\r", start);
                out.push_back(root_path(text.substr(start, end - start)));
                if (end == std::string::npos)
                    break;
            }
            return out;
        };

        /* How an optional path is spelled once it reaches a
         * prerequisite list.  "$(wildcard P)" is the obvious answer,
         * and it is wrong in a state this tree is in all the time.
         *
         * First the two halves it gets right, because they are what
         * the whole convention rests on.  A prerequisite that is
         * absent and that no rule builds is a hard error, so an
         * optional input named outright stops a build that was not
         * even asking for the generated file; "$(wildcard)" of a file
         * that is not there expands to nothing at all, so the rule
         * reads exactly as though the line had never been printed.
         * And a file that IS there but that nothing in the Makefile
         * knows how to build is, to make, simply up to date -- so the
         * very same line becomes a real prerequisite once the file
         * appears, with no reconfigure.  The path may hold make's glob
         * characters, which is how a script names a toolchain whose
         * shape it knows and whose version it does not.
         *
         * What that does NOT buy, and an earlier draft of this comment
         * claimed it did: that the first plain make after the file
         * arrives regenerates the output.  Joining the graph is not
         * being newer than the target, and newer is the only question
         * make asks of an ordinary prerequisite.  Measured: with the
         * input absent at configure time and the output already built,
         *
         *     echo 42 > src/opt/answer.txt
         *     touch -d 2020-01-01 src/opt/answer.txt
         *     make
         *     DEPS	gen.h
         *     make: Nothing to be done for 'all'.
         *
         * and the output still encoded the absent case while the file
         * sat there with content in it.  That state is unreachable for a
         * mandatory input -- an absent one is a hard error, so there is
         * no earlier output for a late arrival to be older than -- so
         * the '?' is what creates it, and tar restoring mtimes is what
         * makes it reachable outside a test.  It is pinned by
         * generate-optional-dep-mtime-inverted.bash.
         *
         * Closing it would mean beating mtime, and mtime is all make
         * has, so the check would have to run whether or not anything
         * moved -- which is a price, and the price was measured rather
         * than guessed at.  Hanging the .d rule off a FORCE does not
         * merely cost time: because the .d is INCLUDED, make remakes
         * it, re-execs, finds it out of date again and re-execs again,
         * and the build never terminates -- 1818 DEPS runs in the 20
         * seconds before the measurement was killed.  Spelling it
         * carefully, so the recipe keeps the old file when the answer
         * has not changed and make therefore has no reason to re-exec,
         * does terminate and costs a --deps subprocess per generated
         * file per make: a no-op make in a one-generator tree went from
         * 1.7 ms to 13 ms.  That is paid by every incremental build in
         * order to catch a backdated arrival, and the trade has not
         * been made -- but it is a trade rather than an impossibility,
         * and the numbers are here so the next person can make it
         * without re-deriving them.
         *
         * The state it gets wrong is a DANGLING SYMLINK.  $(wildcard)
         * answers out of the directory listing rather than by stat, so
         * it reports a symlink whose target is gone as present -- and
         * then make holds a prerequisite that exists by name, cannot
         * be stat'ed, and has no rule, which is exactly the hard error
         * the glob was chosen to avoid, arriving by the one route the
         * glob does not cover.  Measured, with one dangling and one
         * live symlink matching the same pattern:
         *
         *     bare wildcard : [bin/aarch64-dangling-gcc bin/aarch64-real-gcc]
         *     realpath filt : [ bin/aarch64-real-gcc]
         *     $ make -f M2
         *     make: *** No rule to make target 'bin/aarch64-dangling-gcc',
         *     needed by 'out'.  Stop.
         *
         * That is not a corner.  Every name matching glade-vm's glob
         * in the tree this convention was written for is a symlink to
         * one shared "toolchain-wrapper" binary, so any state in which
         * the wrapper is gone and the links are not -- an interrupted
         * buildroot, a half-cleaned host directory, a partially synced
         * obj/ -- stops EVERY target in the tree and not merely the
         * generated one, turning a recoverable toolchain state into an
         * unbuildable tree.  And it falsifies the promise above in the
         * promise's own terms: a file present but owned by nobody is
         * supposed to be simply up to date.
         *
         * So every match is put through $(realpath), which stats and
         * resolves and answers empty for a link with nothing on the
         * end of it, and only the survivors are named.  The result
         * carries one space per dropped match -- " bin/foo" rather
         * than "bin/foo" -- which is nothing whatsoever in a
         * prerequisite list.  Note that it is $(f) and not
         * $(realpath $(f)) that gets named: the filter decides whether
         * a match counts, and must not rename it, or the prerequisite
         * would be an absolute canonical path while every rule that
         * builds the file calls it something else.
         *
         * Two things a reader reasonably worries about here, both
         * measured and both fine.  A path with a ',' in it is not torn
         * in half by $(foreach)'s argument parsing, because the comma
         * sits inside the $(wildcard) parentheses and make only splits
         * arguments at the top level.  And "f" does not clobber a
         * variable of that name: make restores it when the $(foreach)
         * ends, so a Configfile that sets "f" still sees its own value
         * both in later expansions and in recipes.
         *
         * "d" is the dollar sign: "$" where this lands in the Makefile
         * directly, "$$" where it lands inside a recipe make expands
         * before the shell sees it.  One spelling of the filter with
         * the dollar handed in beats two spellings that have to be
         * kept in step by hand, which is the mistake this entire bug
         * is made of.
         *
         * What the filter hands back is read for colons a second time.
         * make finds a rule's colon before it expands anything, which
         * is why a ':' inside the $(wildcard ...) is safe as written,
         * but it reads the expanded prerequisites again for a static
         * pattern rule's -- so a "src/a:b.txt" that the filter found
         * comes back bare and ends in "multiple target patterns", for
         * an input the script marked as one the build can do without.
         * Each survivor is therefore named through a $(subst) that
         * spells its ':' the way makefile::prerequisite() does.  A '#'
         * and a '$' need no such care: a comment is gone before
         * anything is expanded, and what an expansion produces is not
         * expanded again.  "bs" is a backslash as it has to be written
         * where this lands: itself in the Makefile, and doubled in the
         * replacement half of the sed below, where a lone one would
         * escape the ':' away. */
        auto present_only = [](const std::string& path,
                               const std::string& d,
                               const std::string& bs) {
            return d + "(foreach f," + d + "(wildcard " + path + "),"
                 + d + "(if " + d + "(realpath " + d + "(f)),"
                 + d + "(subst :," + bs + ":," + d + "(f)),))";
        };

        /* The complaint about a bare '?', written once because it is
         * made twice: here against the answer pconfigure got, and
         * again in the .d recipe further down against the answer the
         * build gets.  Two hand-kept copies of a diagnostic drift, and
         * a reader who meets the second one should recognise it as the
         * same refusal rather than wonder what else went wrong.
         *
         * It says which script said it, what the '?' means, what to
         * write instead, and that printing nothing at all is a
         * legitimate answer -- that last one because "say nothing" was
         * the habit that caused the original incident, and a reader of
         * this message should not have to infer that it is allowed. */
        auto bare_optional_lines = std::vector<std::string>{
            "'" + ctx->unbased(procfile)
                + " --deps' printed a '?' with no path after it",
            "  a '?' marks the rest of the line as an optional input: "
                "one that is read when",
            "  it is there and done without when it is not.  Write "
                "'?src/thing' -- or print",
            "  nothing at all, which is what a script with no input to "
                "declare should do."
        };

        /* The complaint about a ';', likewise written once for the
         * same two guards.  On a rule line a ';' ends the prerequisites
         * and starts a recipe, so a path with one in it was not merely
         * a wrong file: "src/a;touch PWNED" handed make the input
         * "src/a" and a recipe of "touch PWNED", which overrode the
         * GENERATE recipe -- whatever the script printed after the ';'
         * was run by make as a shell command, in place of the script.
         * Unlike a '#', a '$' or a ':' there is no way to spell one
         * that make reads back as part of a file name: "\;" still ends
         * the list, and so does a ';' inside "$(wildcard ...)", since
         * make looks for it before expanding anything.  So it is
         * refused, on an optional line as much as a mandatory one, and
         * what to do instead is rename the file, since the name is the
         * only thing that can change. */
        auto semicolon_lines = std::vector<std::string>{
            "'" + ctx->unbased(procfile)
                + " --deps' printed a path with a ';' in it",
            "  make reads a ';' on a rule line as the start of a recipe, "
                "and has no way to",
            "  spell one that is part of a file name.  Rename the input "
                "so its name has no",
            "  ';' in it -- or, if it is not an input, stop printing it."
        };

        /* Every way of running the script wrong is fatal, and a fatal
         * error has to name the GENERATE line that asked for it: a
         * tree with a dozen of these is not one where the reader can
         * be expected to work out which line owns "gen.h.proc" from
         * the shell's complaint about it.  The script is named as it
         * is spelled from where pconfigure was run, since that is
         * where a reader is going to go looking for it.
         *
         * The two commonest mistakes are checked for before anything
         * is run, so that they can be told apart and each given its
         * remedy.  Left to the shell, a script that isn't there and a
         * script without its execute bit both come back as nothing
         * better than an exit code -- 127 and 126 -- that a script is
         * also free to exit with on its own account. */
        auto gen_line = std::to_string(ctx->cmd->debug());
        if (access(procfile.c_str(), F_OK) != 0) {
            std::cerr << gen_line << "\n"
                      << "  error: GENERATE += " << ctx->cmd->data()
                      << " runs " << procfile << ", which does not exist\n"
                      << "  that script prints the generated file's inputs"
                      << " when given --deps, and the file itself when"
                      << " given --generate\n"
                      << "  write it there, or drop the GENERATE line if"
                      << " nothing generates " << ctx->cmd->data()
                      << " any more\n";
            abort();
        }
        if (access(procfile.c_str(), X_OK) != 0) {
            std::cerr << gen_line << "\n"
                      << "  error: " << procfile
                      << " is there but is not executable\n"
                      << "  GENERATE runs the script itself rather than"
                      << " handing it to an interpreter, so it needs its"
                      << " execute bit and a #! line\n"
                      << "  chmod +x " << procfile
                      << ", and commit the mode change so a fresh clone"
                      << " gets it too\n";
            abort();
        }

        /* Anything else is the script's own business, and the script
         * has had its say on stderr already, so what is left to add is
         * where it came from, how it ended, and that the way forward is
         * to run it by hand and see.
         *
         * The command to run it by hand is spelled out whole, because
         * the script is not run as it is named above: it is run from
         * the top of its own project, as that project spells it, so
         * that the paths it reads and prints are the ones it was
         * written against.  For a subproject "sub/src/gen.h.proc" is
         * where to find the script but "src/gen.h.proc" is what gets
         * run, from inside "sub/", and an instruction that mixed the
         * two -- "run sub/src/gen.h.proc from sub/" -- names a file
         * that does not exist from where it tells the reader to
         * stand. */
        auto script_failed = [&](const std::string& run,
                                 const std::string& how) {
            auto by_hand = ctx->unbased(procfile) + " " + run;
            if (ctx->base.size() > 0)
                by_hand = "cd " + ctx->base + " && " + by_hand;
            std::cerr << gen_line << "\n"
                      << "  error: '" << procfile << " " << run << "' "
                      << how << "\n"
                      << "  GENERATE runs the script with --deps to learn"
                      << " what " << ctx->cmd->data() << " is made from,"
                      << " then with --generate to make it, and both have"
                      << " to succeed\n"
                      << "  run it by hand to see what went wrong, and fix"
                      << " the script: " << by_hand << "\n";
            abort();
        };

        auto sources = std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(procfile)
        };
        auto dep_lines = file_utils::execlines(
            in_project("\"" + ctx->unbased(procfile) + "\""),
            {"--deps"},
            [&](const std::string& how) { script_failed("--deps", how); });
        for (const auto& line: dep_lines) {
            /* A '?' with nothing but whitespace after it is the one
             * new way there is to write this wrong, and left alone it
             * goes wrong without a word.  From the top of a tree it
             * records a filter over "$(wildcard )", which expands to
             * nothing, so the line is thrown away silently -- an input
             * the script believes it declared and that nothing
             * watches, which is precisely the failure this convention
             * was added to end.  From a subproject it records
             * "$(wildcard sub/)", naming the project's own directory,
             * which is not the file the script meant either.
             *
             * An earlier draft of this comment said the subproject
             * spelling was the worse of the two: that hanging the
             * output off the project directory would regenerate
             * FOREVER, the directory's mtime moving whenever anything
             * in the tree did.  Measured, it does not.  A file created
             * two levels down (sub/src/marker) moves sub/'s mtime not
             * at all and triggers no regeneration whatsoever; a direct
             * child (sub/marker) regenerates exactly once and then
             * settles -- GEN counts of 1, 0, 0 over three successive
             * makes.  A directory's mtime answers for its direct
             * children and for nothing deeper, and what comes of it is
             * a stale output and the occasional spurious rebuild, not
             * a loop.
             *
             * So the argument for refusing is the one that was
             * reproduced rather than the one that was not: both
             * spellings quietly name something other than the input
             * the script asked to watch.  Guessing which file it meant
             * is not on the table, and the script that printed the
             * line can be named from here. */
            if (optional_dep(line) == true
                && optional_path(line).size() == 0) {
                for (const auto& l: bare_optional_lines)
                    std::cerr << l << "\n";
                std::cerr << std::to_string(ctx->cmd->debug()) << "\n";
                abort();
            }

            /* Checked before the line is split into paths, because the
             * line is what lands on the rule line and a ';' anywhere
             * in it -- in a path or between two -- ends it there.  The
             * GENERATE line comes first, as it does when the script
             * fails, and the line the script printed last, so the
             * reader can see which of its inputs has the name to
             * change. */
            if (line.find(';') != std::string::npos) {
                std::cerr << std::to_string(ctx->cmd->debug()) << "\n";
                for (const auto& l: semicolon_lines)
                    std::cerr << l << "\n";
                std::cerr << "  it printed: " << line << "\n";
                abort();
            }

            /* What it printed is relative to itself.  An optional
             * line naming several paths keeps them inside the one
             * filter, the way the fragment below spells it, since
             * $(wildcard) takes a list as readily as a single
             * pattern.
             *
             * Each path is whatever the script printed, so it is
             * spelled for where it lands, which the two kinds of line
             * do differently: a mandatory path lands bare on the rule
             * line, where a '#' cuts it short, a '$' expands and a ':'
             * makes a second rule separator, and an optional one lands
             * inside the filter's function calls, where only the '$'
             * does -- the filter itself sees to the ':' in what it
             * finds. */
            auto paths = dep_paths(line);
            if (optional_dep(line) == true) {
                auto joined = std::string();
                for (const auto& path: paths)
                    joined += (joined.size() == 0 ? "" : " ")
                            + makefile::function_argument(path);
                sources.push_back(
                    std::make_shared<makefile::target>(
                        present_only(joined, "$", "\\")));
            } else {
                for (const auto& path: paths)
                    sources.push_back(
                        std::make_shared<makefile::target>(
                            makefile::prerequisite(path)));
            }
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        /* The generated file is written to a temporary and moved into
         * place rather than redirected into, so that a --generate
         * which fails leaves nothing at all behind.  A raw redirect
         * creates the target before the script has said one word, so a
         * script that dies halfway through leaves a truncated file
         * carrying an mtime newer than every prerequisite it has --
         * which the next make calls up to date, and every consumer
         * then compiles against.  The configure-time run just below
         * makes that worse rather than better: it generates only when
         * the target is missing, so a truncated file from a failed
         * configure is a file no later pconfigure reconsiders either.
         * The rule to keep is the one makefile.c++ keeps for the check
         * reports -- the target exists if and only if the last run
         * that wrote it succeeded -- which leaves absence as the one
         * state a reader cannot misread.
         *
         * That file argues the whole case at length and records which
         * shapes were tried and rejected, so this is the short
         * version: writing the file out anyway and then exiting 1 is
         * worse than it looks, because it leaves a target newer than
         * its prerequisites and the next make has nothing to do; and
         * ".DELETE_ON_ERROR:" is neither available nor sufficient --
         * it is file-global, and make deletes a failed recipe's target
         * only when the recipe got as far as changing it, which with
         * an "&&" in front of the mv it never does.
         *
         * The subshell is not decoration.  in_project() puts a "cd" on
         * the front for a script belonging to a subproject, and an
         * unbracketed "cd sub/. && script --generate > t.tmp && mv ..."
         * hands a cd that failed to the same "||" as a script that
         * failed -- so the recipe would rm the target because it could
         * not find the directory to generate it in.  Bracketing the cd
         * and the script together and hanging the redirect off the
         * group is what dep_commands below does, for exactly this
         * reason.  And nothing here may use "$@", however much shorter
         * it reads: this same string is handed to system() a few lines
         * down, where "$@" is the shell's empty argument list rather
         * than make's target.
         *
         * One thing this does take away, and it is worth naming because
         * the raw redirect gave it away by accident rather than on
         * purpose: a script that ignored the contract and wrote the
         * target's file itself instead of printing it used to work,
         * because the shell's redirect and the script's own write
         * landed on the same path and the script's went last.  Now the
         * redirect lands on the temporary, so such a script has its
         * work moved over by whatever it printed -- which, for a script
         * that printed nothing, is an empty file.  There is no way to
         * keep both: "move it only if something was printed" would
         * refuse to generate the empty output that a script with
         * nothing to say is entitled to produce, which is exactly what
         * glade-vm's fixture scripts produce when the toolchain they
         * look for is not there.  "--generate prints the generated
         * file" is what the manual has always said, and it is now what
         * it means.
         *
         * And the temporary is moved into place only when it says
         * something the target did not already say, which is the one
         * thing standing between a prerequisite that was REWRITTEN and
         * a consumer that gets rebuilt.  make's question about a
         * prerequisite is "is it newer than the target", and a script
         * whose answer is a function of its inputs' CONTENT has inputs
         * whose mtime moves without their content moving: a file
         * rewritten with the bytes it already had is the ordinary
         * shape of a cache being repacked.  A rule that always mv'd
         * passed that straight through, so the output came back
         * byte-identical with a new mtime and everything downstream of
         * it rebuilt for nothing.
         *
         * Measured in the tree that vendors this, which is where this
         * stops being tidiness.  Its glibc and xfstests conformance
         * harnesses each watch a stamp whose body is `git rev-parse
         * HEAD` for a submodule, and the files that body is read out of
         * are .git's HEAD, the branch ref and packed-refs.  `git
         * pack-refs` rewrites packed-refs, and so does the auto-gc any
         * `git fetch` may trigger -- for a revision that did not move.
         * The stamp then regenerated identical, and an hours-long suite
         * re-ran to produce the verdicts it had already produced.  That
         * is a whole night of machine time for a `git gc`, and the
         * declaration cannot be narrowed to avoid it: a branch's tip
         * lives in the loose ref until it is packed and in packed-refs
         * afterwards, so watching one and not the other misses the move
         * itself.  The content was always the authority; nothing was
         * asking it.
         *
         * What it COSTS is that such a rule no longer settles, and that
         * is the honest half.  The target stays older than the
         * prerequisite that was touched, so make asks again on the next
         * build, and on every build after it, until something actually
         * changes the output.  The script therefore runs every make
         * once one of its inputs has been rewritten in place -- cheap
         * for a script whose job is to print a revision, not cheap for
         * one that builds an archive, and there is no third option
         * available: mtime is all make has, and a target cannot be
         * newer than its prerequisite while staying older than its
         * consumers.  Leaving it alone is still the better trade, since
         * what it buys back is bounded by the cost of the CONSUMERS
         * rather than of the script.  The settling shape would be a
         * second witness file, touched unconditionally, with the output
         * hanging off it -- two targets and a name per GENERATE, for a
         * re-run of a script that is already a prerequisite of
         * everything it feeds.  Not worth it until a GENERATE shows up
         * that is expensive AND insensitive to its inputs' mtimes.
         *
         * The spelling is build_systems/cmake.c++'s, which asks this
         * same question of the options file it writes beside a vendored
         * build, down to the "2>/dev/null" that keeps a cmp with no
         * target to compare against quiet.  It is braced so that the
         * "||" below still reaches a failed mv: the rule that a target
         * exists if and only if the last run that wrote it succeeded is
         * the rule this recipe is mostly about, and a cmp in the middle
         * of the chain may not be the thing that quietly ends it. */
        auto tmp_target = temporary_path(target);
        auto short_cmd = "GEN\t" + ctx->cmd->data();

        /* The directory made is the one the output goes in, which is
         * not always the generated-files directory itself: a GENERATE
         * of "sub/gen.h" writes obj/proc/sub/gen.h, so that it is
         * found by the '#include "sub/gen.h"' that asked for it, and
         * making only obj/proc left the redirect below with nowhere
         * to write.  It is cut from the target rather than spelled as
         * "$(dir $@)" because these same lines are run through
         * system() at configure time, where there is no make to
         * expand that -- and the target always has a '/', since it
         * starts with the generated-files directory. */
        auto target_dir = target.substr(0, target.rfind('/'));
        auto commands = std::vector<std::string>{
            "mkdir -p " + target_dir,
            "(" + in_project(ctx->unbased(procfile) + " --generate")
                + ") > " + tmp_target
                + " && { if cmp -s " + tmp_target + " " + target
                + " 2>/dev/null;"
                + " then rm -f " + tmp_target + ";"
                + " else mv " + tmp_target + " " + target + "; fi; }"
                + " || (rm -f " + tmp_target + " " + target + "; exit 1)"
        };

        /* Which script writes the output is the Configfile's to say: a
         * GENERATE runs src/<name>.proc and a TGENERATE test/<name>.proc,
         * and a SRCDIR above the line moves it again.  Changing any of
         * those leaves an output on disk that the OLD script wrote, and
         * make has no way of telling: the new script is a prerequisite,
         * but it is usually older than the output -- the ordinary state
         * of a checkout -- so the rule is satisfied and the old answer
         * stays until somebody runs "make clean".  A BASH script and a
         * HEADERS copy have the same problem and keep a record of their
         * recipe for it (see language::recipe_record()), and so does
         * this.
         *
         * Unlike theirs, the record is not hung off the rule as a
         * prerequisite, and that is down to the "cmp" in the recipe
         * above.  A record that changed is newer than the output; the
         * new script then runs, and when it prints what the old one
         * printed the output is deliberately left alone -- so it stays
         * older than the record, and make would run the script again on
         * every build from then on.  Pointing a GENERATE at a copy of
         * its script is not an exotic thing to do.  So the record is
         * read here instead, by the configure that changed the recipe,
         * and a record that says something else gets the output written
         * again now, the same way a missing output is: through the
         * recipe itself, so that an unchanged answer leaves the output
         * and everything compiled from it alone.  The record can then
         * be as new as it likes, since no rule asks.
         *
         * A record that isn't there says nothing about the output beside
         * it, the way recipe_record() treats one: that is a tree
         * configured before records were kept, or one whose object
         * directory was thrown away, in which case the output went with
         * it.  Written through recipe_record() all the same, so that the
         * record has the one name and the one spelling every other
         * record has, and so that the Makefile can write it back -- which
         * is also what keeps "make cache-clean", which deletes from the
         * object directory whatever the Makefile doesn't name, from
         * throwing it away and with it the next switch of script.
         *
         * The record is written after the run, not before.  A configure
         * that dies in the middle then leaves the old record beside
         * whatever is there, which the next configure finds mismatched
         * and runs again; the other order would leave the new record
         * vouching for the old output. */
        auto recipe_path = recipe_record_path(ctx, target);
        auto recipe = std::string();
        for (const auto& line: commands)
            recipe += line + "\n";
        auto recipe_changed = access(recipe_path.c_str(), F_OK) == 0
            && file_utils::says(recipe_path, recipe) == false;

        /* We actually issue the generate commands here, as that's the only way
         * to tell the rest of pconfigure these commands have actually been
         * generated.
         *
         * And not only when there is no output yet, which is what this
         * used to ask.  What a generated header includes is read off
         * the copy sitting here, by the scan that decides what a
         * binary links and what its objects depend on, so a copy the
         * script's last edit has made stale is a copy that answers
         * those questions for the old script.  A rerun after editing
         * gen.h.proc to include helper.h left helper.c unlinked and
         * the next make failing on an undefined reference, and a
         * header with no source behind it was put on no rule at all;
         * both went away only on a second pconfigure, by which time
         * make had regenerated the output.
         *
         * So this asks make's question of the inputs the rule above
         * names: the script and everything its --deps answer printed.
         * That means the script runs here exactly when the next make
         * would have run it anyway, and an output that is up to date
         * costs a reconfigure nothing.  "Always regenerate, and keep
         * the old file if nothing changed" was the other shape, and
         * it was rejected for that cost: a GENERATE that builds an
         * archive would rebuild it on every configure.  An optional
         * input is expanded the way the rule's $(wildcard) would
         * expand it, since its path may be a pattern.  What the build
         * later discovers through the fragment below is not consulted
         * -- but the --deps that just ran here is the same question
         * asked again, so a newly read input is already in the answer.
         *
         * The recipe itself still decides whether the file is
         * replaced, so a script that runs and says what it said
         * before leaves the output, and its mtime, as they were.
         *
         * A script that is older than the output but isn't the one that
         * wrote it is the case mtimes can't see, which is what the
         * recipe record above is for. */
        auto stale = access(target.c_str(), R_OK) != 0
            || file_utils::newer_than(procfile, target);
        for (const auto& line: dep_lines) {
            for (const auto& path: dep_paths(line)) {
                if (optional_dep(line) == false) {
                    stale = stale || file_utils::newer_than(path, target);
                    continue;
                }

                glob_t matches;
                if (glob(path.c_str(), 0, NULL, &matches) == 0)
                    for (size_t i = 0; i < matches.gl_pathc; ++i)
                        stale = stale
                            || file_utils::newer_than(matches.gl_pathv[i],
                                                      target);
                globfree(&matches);
            }
        }

        if (stale == true || recipe_changed == true) {
            auto status = system(commands[0].c_str());
            if (status != 0) {
                std::cerr << gen_line << "\n"
                          << "  error: '" << commands[0] << "' "
                          << file_utils::describe_wait_status(status)
                          << "\n"
                          << "  " << ctx->gen_dir << " is where "
                          << ctx->cmd->data() << " gets generated, so it"
                          << " has to be a directory pconfigure can"
                          << " write\n";
                abort();
            }

            /* The status is not decoded here, because there is nothing
             * left of the script's in it: the recipe's "|| (rm ...;
             * exit 1)" turns every failure into a 1, so that make sees
             * a failure whatever the script exited with.  Reporting
             * "exited with status 1" for a script that exited 3 would
             * be a precise-looking wrong answer, so this says only that
             * it failed -- which is all that is known. */
            if (system(commands[1].c_str()) != 0)
                script_failed("--generate", "failed");
        }

        recipe_record(ctx, target, commands);

        auto filename = ctx->cmd->debug()->filename();
        auto lineno = ctx->cmd->debug()->line_number();
        auto comment = std::vector<std::string>{
            "language_gen_proc::targets()",
            filename + ":" + std::to_string(lineno)
        };

        auto bin_target = std::make_shared<makefile::target>(target,
                                                             short_cmd,
                                                             sources,
                                                             global_targets,
                                                             commands,
                                                             comment);

        /* The --deps answer above is a snapshot: it was true when
         * pconfigure ran, and a script that discovers its inputs -- a
         * glob over a directory, most often -- has inputs that can
         * arrive after that.  The file that arrived is on no rule and
         * bumps nothing the Makefile names, so the output sits there
         * quietly out of date until somebody reconfigures by hand,
         * which is the one thing an incremental build may not ask
         * for.
         *
         * So the snapshot does not get the last word.  Beside the
         * rule sits a fragment saying what the script reads *now*,
         * written the way pdeps writes what a source reads: a rule
         * that runs --deps during the build, and an include of what
         * it said, whose lines are more prerequisites for the rule
         * above.  make remakes what it includes before it reads it,
         * so the same make that is about to need the answer
         * re-derives it, and an input that arrived after the
         * configure lands on the rule with nothing noticed by hand.
         *
         * What trips the re-derivation is the script and the
         * directories the configure-time answer named.  The script,
         * because a script that reads differently reports
         * differently.  The directories, because a file that does not
         * exist yet cannot be a prerequisite, and a directory is the
         * thing whose mtime moves when one arrives -- which is the
         * only shape of "new" make can see coming.  They are watched
         * from the configure-time answer rather than re-derived with
         * it: a fragment would have to be remade to learn that it
         * should be remade.  A script that starts reading a directory
         * it did not read at configure time edits itself to say so,
         * and the script is a prerequisite of everything here.
         *
         * The lines the fragment carries are spelled the way the rule
         * above is spelled, through the project's variable, so that
         * both name the same file whether make ran in the project or
         * over it.  The "$$" is what survives the trip here: make
         * expands one dollar of a recipe before the shell sees it,
         * and the fragment has to still hold the reference when the
         * file reading it gets expanded too. */
        auto deps_path = fragment_path(target);

        /* An optional input's directory is watched like any other
         * one, and the reason is not the arrival of the optional input
         * itself: the "$(wildcard)" on the rule above hears that one
         * already, on the next plain make, without the fragment having
         * to be re-derived at all.  It is watched for the case the
         * mandatory lines are watched for -- a script that globs a
         * directory and prints what it found, one optional line per
         * match, reports a different answer once a sibling shows up,
         * and that answer lives in the fragment rather than in the
         * snapshot.  A directory that is not there expands to nothing,
         * so watching the place a toolchain will one day be installed
         * costs a build that never installs one precisely nothing. */
        auto watched = std::set<std::string>();
        for (const auto& line: dep_lines) {
            for (const auto& based: dep_paths(line)) {
                auto slash = based.rfind('/');
                watched.insert(slash == std::string::npos
                               ? std::string(".")
                               : slash == 0
                               ? std::string("/")
                               : based.substr(0, slash));
            }
        }

        /* And the script's own directory, for a script whose glob was
         * empty when pconfigure ran: there is nothing in the answer
         * above to watch, and an input arriving into that emptiness
         * is the case this exists for. */
        {
            auto slash = procfile.rfind('/');
            watched.insert(slash == std::string::npos
                           ? std::string(".") : procfile.substr(0, slash));
        }

        /* Never watch the directory the target itself lands in.  The
         * recipe above writes both the generated file and this very
         * .d fragment into that directory, so watching it makes the
         * rule its own trigger: build it once and $(wildcard <dir>)
         * is newer than what was just built, forever.  A script that
         * genuinely wants to notice a sibling of its own output has
         * no way to ask for that today, but an infinite rebuild loop
         * is a worse answer than missing that one case. */
        {
            auto slash = target.rfind('/');
            watched.erase(slash == std::string::npos
                          ? std::string(".") : target.substr(0, slash));
        }

        /* The watched directories go through the same filter the
         * optional paths do, and for the same measured reason: a
         * directory that is a dangling symlink is listed by $(wildcard)
         * and cannot be stat'ed, so it wedges this rule -- and this
         * rule is an include, so wedging it wedges the Makefile and
         * every target in it.  A half-cleaned host directory leaves
         * exactly that: "obj/.../host/bin" gone and the link to it
         * still there.
         *
         * The script itself is deliberately NOT filtered.  It is a
         * mandatory input, it is named outright on the rule above, and
         * a dangling one is a build that cannot run --generate at all.
         * Filtering it would turn that into a fragment that is never
         * re-derived, which is a quieter way to be broken. */
        auto dep_deps = std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(
                "$(wildcard " + procfile + ")")
        };
        for (const auto& dir: watched)
            dep_deps.push_back(
                std::make_shared<makefile::target>(
                    present_only(makefile::function_argument(dir),
                                 "$", "\\")));

        auto variable = ctx->base.size() == 0
            ? std::string()
            : "$$(" + project::prefix_variable(ctx->base) + ")";

        /* The '?' of an optional line has to be read here as well as
         * at configure time, and sed is where that happens, because
         * this answer is the script's live one rather than the
         * snapshot above: a line reaching the fragment named outright
         * is a prerequisite make has no rule for, which is the hard
         * error the whole convention exists to avoid.
         *
         * The ORDER is the trick, and it is upside down from the
         * obvious one.  The expression that turns an optional line
         * into a rule runs LAST, and the one that does the same for an
         * ordinary line carries a "/^?/!" address so an optional line
         * walks past it untouched.  Each line therefore becomes a rule
         * exactly once, and no expression has to undo another's work.
         * (In a subproject the paths on a line are rooted before
         * either of those runs; that part is the same for both kinds
         * of line apart from where the first word starts, and is
         * explained where it is written.)
         *
         * Written the other way round -- optional first, then a "t" to
         * branch the finished line away from the rest -- it also works,
         * and the worry that it would not work on BSD sed turned out to
         * be unfounded rather than confirmed, which is worth recording
         * so that nobody pays for it twice.  A "t" with no label is
         * branch-to-end-of-script there: FreeBSD's compile.c sets
         * cmd->t to NULL when the branch argument is empty and
         * fixuplabel reads a NULL target as the end of the script, and
         * Apple's text_cmds snapshot -- which is the sed macOS actually
         * ships -- carries those same lines unchanged.  Measured rather
         * than read, too: the two orderings, emitting the identical
         * filter so that the ORDER is the only variable, produced
         * byte-identical output over every line shape this sed sees --
         * mandatory, optional, a glob, a path with a space in it, a
         * path with the sed delimiter '|' in it, and a '?' with
         * whitespace before the path -- in all four combinations of
         * {GNU sed 4.10, a FreeBSD sed built from source for the
         * comparison} x {top of tree, subproject}.
         *
         * That last shape is also the delimiter check this filter
         * needs, and it passes for a duller reason than it sounds: the
         * text being substituted IN holds commas, parentheses and
         * dollars but no '|' and no '&', and sed does not re-read the
         * delimiter inside what \1 captured.
         *
         * The addresses win anyway, for a reason that has nothing to do
         * with portability: a "t" guards the expressions after it from
         * a distance, so the next person to append an "-e" to this list
         * gets it silently applied to optional lines as well, with
         * nothing near what they wrote to mention the branch.  An
         * address is written on the expression it guards.  When this
         * Makefile goes wrong it goes wrong by naming the WRONG file in
         * a perfectly valid fragment, which is this bug's whole family,
         * so the spelling that cannot be broken from a distance beats
         * the one that reads shorter.
         *
         * A '?' cannot collide with a real path in those addresses.  An
         * ordinary line beginning with one would have been an optional
         * line -- that is what the convention spent the character on --
         * and rooting a line's words, below, never puts a '?' on the
         * front of a line that did not start with one.
         *
         * Two spellings are load-bearing and neither is obvious.  "$$("
         * is what a literal "$(" has to be written as, because make
         * expands this recipe before the shell ever sees it -- the same
         * trick the variable reference above is already playing.  And
         * the '$' that would naturally anchor the end of the pattern is
         * left off deliberately: "$|" in a recipe is make expanding a
         * variable named '|', which eats the dollar and leaves sed a
         * pattern it did not mean, while a greedy ".*" already reaches
         * the end of the line and asks make for nothing. */
        auto dep_sed = std::string();

        /* What the script printed is spelled for make before anything
         * else touches it, the way makefile::prerequisite() spells it
         * for the snapshot above: a '$' doubled, and a '#' or a ':'
         * escaped with its leading backslashes doubled, on an ordinary
         * line only -- an optional line's paths land inside function
         * calls, where a '#' is an ordinary character and a ':' is
         * looked after by the filter's $(subst).  First,
         * because every expression after this one writes make syntax
         * of its own onto the line -- the subproject's variable, the
         * filter's "$(" -- and escaping after them would escape that
         * too.
         *
         * In the recipe's own spelling, so doubled once more for the
         * '$': "\$$" is a sed pattern for a dollar and "$$$$" is a
         * replacement of two of them, once make has expanded the
         * recipe. */
        dep_sed += "-e 's|\\$$|$$$$|g' ";
        dep_sed += "-e '/^?/!s|\\(\\\\*\\)#|\\1\\1\\\\#|g' ";
        dep_sed += "-e '/^?/!s|\\(\\\\*\\):|\\1\\1\\\\:|g' ";

        /* A subproject roots each path a line names, the way
         * dep_paths() above does for the snapshot, and the two have to
         * agree: they are both prerequisites of the one rule, so a
         * path the snapshot roots correctly and the fragment does not
         * is the same failure with one step of indirection.  Pasting
         * the variable onto the front of the LINE is what used to
         * happen here, and it went wrong in the same four ways that
         * comment lists -- worst for an optional absolute path, which
         * became "$(wildcard sub//opt/x)", a glob that can never match,
         * so the input arriving regenerated nothing and nobody was
         * told.
         *
         * So a word gets the variable when it starts at the front of
         * the line or after whitespace, and its first character is
         * neither whitespace nor a '/'.  That is three expressions
         * rather than one because POSIX BRE has no alternation to
         * spell "start of line or whitespace" with -- "\|" is a GNU
         * extension -- and an optional line's first word sits behind
         * its '?'.  The first expression squeezes the whitespace after
         * a '?' away so that the second has one spelling to look for.
         * The "g" on the last one is safe because each match consumes
         * the whitespace it starts at, so a run of words is rooted one
         * word per match and none of them twice. */
        if (variable.size() > 0) {
            dep_sed += "-e 's|^?[[:space:]]*|?|' ";
            dep_sed += "-e '/^?/!s|^\\([^/[:space:]]\\)|"
                     + variable + "\\1|' ";
            dep_sed += "-e 's|^?\\([^/[:space:]]\\)|?"
                     + variable + "\\1|' ";
            dep_sed += "-e 's|\\([[:space:]]\\)\\([^/[:space:]]\\)|\\1"
                     + variable + "\\2|g' ";
        }
        dep_sed += "-e '/^?/!s|.*|" + variable + ctx->unbased(target)
                 + ": &|' ";
        dep_sed += "-e 's|^?[[:space:]]*\\(.*\\)|" + variable
                 + ctx->unbased(target) + ": "
                 + present_only("\\1", "$$", "\\\\") + "|'";

        /* The same refusal the configure-time guard above makes, on
         * the path where it actually matters.  That guard reads the
         * answer PCONFIGURE got; this one reads the answer the BUILD
         * gets, and they are different answers -- editing a .proc
         * script triggers this rule rather than a reconfigure, so a
         * script that starts printing a bare '?' reaches the sed below
         * and nothing else.  Measured on the draft this replaces, with
         * a script that declared "src/base.txt" and began printing a
         * bare '?' as well once a marker file appeared: the build
         * succeeded, exit 0, nothing said, and the fragment grew
         *
         *     obj/proc/gen.h: $(wildcard )
         *
         * at the top of a tree, which expands to nothing -- so the
         * input the script believes it declared is watched by nothing
         * whatsoever, which is this bug exactly, on the one path that
         * exists because answers change after a configure.  From a
         * subproject the same line comes out "$(wildcard sub/)" and
         * make resolves it to the project's own directory: not a drop,
         * but not the file the script named either.
         *
         * One thing it does NOT do, because the first draft of this
         * comment said it did and the measurement says otherwise: no
         * previously-declared mandatory input is lost.  The fragment
         * ADDS prerequisites rather than replacing the rule's, so the
         * configure-time snapshot goes on naming src/base.txt -- "make
         * -p" still reports it, and editing it still regenerates (BASE
         * went to 9 on the next make).  The damage is confined to the
         * optional line, and that is damage enough.
         *
         * The wording is not a copy of the configure-time message but
         * the same strings, built above where both guards can reach
         * them, so that the two cannot drift apart: they are reached by
         * different routes and a reader who has seen one should
         * recognise the other rather than wonder whether it is a
         * different complaint.  "[[:space:]]*" rather
         * than a literal space, so that "? " is refused here exactly as
         * it is up there; "$$" is a literal '$' for sed, make eating
         * one of the two on the way through.  And $@.raw is removed, so
         * the next make re-runs the script rather than reading a file
         * that was already refused once. */
        auto bare_optional_echo = std::string();
        for (const auto& l: bare_optional_lines)
            bare_optional_echo += "echo \"" + l + "\"; ";

        /* The ';' refusal, made here for the same reason the bare '?'
         * one is: an edited script reaches this recipe and never the
         * configure-time guard, and this is where a ';' would reach a
         * rule line.  The fragment is included, so it is the Makefile
         * as far as make is concerned, and a ';' let through into it
         * is a recipe make runs on the next pass.  The offending lines
         * are printed after the explanation, as the configure-time
         * message prints its one. */
        auto semicolon_echo = std::string();
        for (const auto& l: semicolon_lines)
            semicolon_echo += "echo \"" + l + "\"; ";

        auto dep_commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            "(" + in_project("\"" + ctx->unbased(procfile) + "\" --deps")
                  + ") > $@.raw || (rm -f $@.raw; exit 1)",
            "if grep -q '^?[[:space:]]*$$' $@.raw; then "
            "{ " + bare_optional_echo + "} >&2; "
            "rm -f $@.raw; exit 1; fi",
            "if grep -q ';' $@.raw; then "
            "{ " + semicolon_echo
                 + "sed -n 's|^|  it printed: |p' $@.raw | grep ';'; "
            "} >&2; rm -f $@.raw; exit 1; fi",
            "sed " + dep_sed + " $@.raw > $@.tmp"
                  + " && mv $@.tmp $@"
                  + " || (rm -f $@.raw $@.tmp; exit 1)"
        };

        /* The recipe above, written down beside the fragment it makes,
         * and the fragment thrown away when the two no longer match.
         *
         * A fragment is not the answer the script gave: it is what one
         * version of this recipe made of that answer.  The script is a
         * prerequisite already and the directories it reads are
         * watched, so a changed ANSWER is noticed.  What nothing was
         * watching is a changed QUESTION -- the sed above, which is
         * where the whole format of the fragment lives -- so a
         * pconfigure that learns to write the fragment differently
         * leaves every fragment already on disk saying the old thing,
         * with a Makefile beside it that says the new one.
         *
         * Measured in the tree that vendors this, on the configure that
         * first taught "--deps" the '?' marker.  The fragment on disk
         * had been written by the previous recipe, which knew nothing
         * of the marker and so prefixed the line without stripping it:
         *
         *     make: *** No rule to make target
         *     'src/pconfigure/?../../.git/modules/src/pconfigure/HEAD',
         *     needed by 'src/pconfigure/obj/proc/version.h'.  Stop.
         *
         * A fragment is INCLUDED, so that is not one stale target: it
         * stops every target in the tree.
         *
         * Dropped at configure time rather than named as a prerequisite
         * of the rule, and that is the part worth measuring before
         * believing.  Naming it looks like the tidier answer -- it is
         * what cxx does with the context it hands pdeps -- and in this
         * tree it does not work: by the time make could act on it the
         * stale fragment has already been read, and its lines are in
         * force while make is still deciding what to remake.  A tree
         * that bootstraps its own pconfigure remakes the top Makefile
         * first, which means building pconfigure, which means the
         * generated header, whose prerequisites now include the bad
         * line -- so make dies on the fragment before reaching the rule
         * that would have rewritten it.  Measured with the prerequisite
         * in place and a context file newer than the fragment: the
         * error above, unchanged, and no recovery from any make at all.
         * The record therefore has to be read by whoever can act before
         * make reads anything, and that is the configure.
         *
         * What it costs when the recipe has not changed is one file
         * read, which is why the question is asked of the content
         * rather than of the file's mtime: a configure that changed
         * nothing must leave the fragment alone, or every configure
         * re-runs every "--deps" script in the tree.
         *
         * The recipe is recorded whole rather than just the sed, so
         * that a change to any part of it -- the guard, the ".raw"
         * plumbing, the rename -- counts, and so that there is no
         * second list here to be kept in step with the first.
         *
         * The fragment goes before the record, and that order is the
         * difference between a safe interruption and a silent one.  A
         * configure killed between the two leaves the old record with
         * no fragment, which the next make simply derives again.
         * Written the other way round it would leave the new record
         * beside the OLD fragment, and every configure after that would
         * find the record matching and the fragment wrong -- the state
         * this whole comment is about, now immune to the thing that
         * fixes it.
         *
         * The leftovers go with it.  A ".raw" is the answer the last
         * run got and a ".tmp" is a fragment that was being written
         * when something died; both are read by the recipe that is
         * about to run under a recipe that is no longer the one that
         * wrote them.
         *
         * One record per fragment, under one name, because the fragment
         * has one name.  The kconfig build system suffixes its contexts
         * per project, since a vendored tree is described once from
         * inside a subproject and once from the top; doing that here
         * would leave the standalone record saying what it said before
         * a parent's build ever ran, so it would MATCH while the
         * fragment beside it had been written by the parent's recipe --
         * a key that has stopped describing the thing it is the key
         * for.  Shared, a mismatch always means what it says.
         *
         * What such a fragment does when it is believed is measured and
         * is quieter than it sounds, which is the argument for fixing it
         * here rather than waiting for a build to complain.  Read from
         * inside the subproject a parent's fragment collapses to the
         * right thing, the project's own Makefile defining its prefix
         * variable as empty; read from the parent a standalone fragment
         * goes on naming the unprefixed target, which that build never
         * asks for, so its lines are inert.  Both builds go green, and
         * an input arriving later is watched by nothing in either. */
        auto dep_context = fragment_context_path(target);
        auto dep_context_content = std::string();
        for (const auto& command: dep_commands)
            dep_context_content += command + "\n";

        if (file_utils::says(dep_context, dep_context_content) == false) {
            unlink(deps_path.c_str());
            unlink((deps_path + ".raw").c_str());
            unlink((deps_path + ".tmp").c_str());
            file_utils::write_if_changed(dep_context, dep_context_content);
        }

        auto deps_target = std::make_shared<makefile::target>(
            deps_path,
            "DEPS\t" + ctx->cmd->data(),
            dep_deps,
            std::vector<makefile::global_targets>{
                makefile::global_targets::CLEAN
            },
            dep_commands,
            comment
        )->as_included();

        return {bin_target, deps_target};
        break;
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}
