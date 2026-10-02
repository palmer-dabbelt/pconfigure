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
#include <set>
#include <unistd.h>
#include <iostream>

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

        /* The path a --deps line names, spelled the way the Makefile
         * spells it: relative to where pconfigure ran, with the
         * owning project on the front, and with the optional marker
         * off.  Everything downstream of here wants the path rather
         * than the line, and the marker left on one of them is a
         * prerequisite named "?src/thing" that nothing will ever
         * build. */
        auto dep_path = [&](const std::string& line) {
            return ctx->base + (optional_dep(line) == true
                                ? optional_path(line) : line);
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
         * is made of. */
        auto present_only = [](const std::string& path,
                               const std::string& d) {
            return d + "(foreach f," + d + "(wildcard " + path + "),"
                 + d + "(if " + d + "(realpath " + d + "(f)),"
                 + d + "(f),))";
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

        auto sources = std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(procfile)
        };
        auto dep_lines = file_utils::execlines(
            in_project("\"" + ctx->unbased(procfile) + "\""),
            {"--deps"});
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

            /* What it printed is relative to itself. */
            sources.push_back(
                std::make_shared<makefile::target>(
                    optional_dep(line) == true
                    ? present_only(dep_path(line), "$")
                    : dep_path(line)));
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
         * it means. */
        auto tmp_target = target + ".tmp";
        auto short_cmd = "GEN\t" + ctx->cmd->data();
        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->gen_dir,
            "(" + in_project(ctx->unbased(procfile) + " --generate")
                + ") > " + tmp_target
                + " && mv " + tmp_target + " " + target
                + " || (rm -f " + tmp_target + " " + target + "; exit 1)"
        };

        /* We actually issue the generate commands here, as that's the only way
         * to tell the rest of pconfigure these commands have actually been
         * generated. */
        if (access(target.c_str(), R_OK) != 0) {
            for (const auto& cmd: commands) {
                if (system(cmd.c_str()) != 0) {
                    std::cerr << "system(" << cmd << ") failed" << std::endl;
                    abort();
                }
            }
        }

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
        auto deps_path = target + ".d";

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
            auto based = dep_path(line);
            auto slash = based.rfind('/');
            watched.insert(slash == std::string::npos
                           ? std::string(".") : based.substr(0, slash));
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
                    present_only(dir, "$")));

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
         * obvious one.  The expression that rewrites optional lines
         * runs LAST, and the two that handle ordinary lines each carry
         * a "/^?/!" address so an optional line walks past them
         * untouched.  Each line therefore gets exactly one rewrite,
         * and no expression has to undo another's work.
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
         * and by the time the second address is tested a subproject's
         * line is already carrying its variable on the front.
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
        if (variable.size() > 0)
            dep_sed += "-e '/^?/!s|^|" + variable + "|' ";
        dep_sed += "-e '/^?/!s|.*|" + variable + ctx->unbased(target)
                 + ": &|' ";
        dep_sed += "-e 's|^?[[:space:]]*\\(.*\\)|" + variable
                 + ctx->unbased(target) + ": "
                 + present_only(variable + "\\1", "$$") + "|'";

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

        auto dep_commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            "(" + in_project("\"" + ctx->unbased(procfile) + "\" --deps")
                  + ") > $@.raw || (rm -f $@.raw; exit 1)",
            "if grep -q '^?[[:space:]]*$$' $@.raw; then "
            "{ " + bare_optional_echo + "} >&2; "
            "rm -f $@.raw; exit 1; fi",
            "sed " + dep_sed + " $@.raw > $@.tmp"
                  + " && mv $@.tmp $@"
                  + " || (rm -f $@.raw $@.tmp; exit 1)"
        };

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
