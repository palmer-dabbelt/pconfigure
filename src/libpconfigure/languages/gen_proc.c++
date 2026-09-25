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

        auto sources = std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(procfile)
        };
        auto dep_lines = file_utils::execlines(
            in_project("\"" + ctx->unbased(procfile) + "\""),
            {"--deps"});
        for (const auto& line: dep_lines) {
            /* What it printed is relative to itself. */
            sources.push_back(
                std::make_shared<makefile::target>(ctx->base + line));
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        auto short_cmd = "GEN\t" + ctx->cmd->data();
        auto commands = std::vector<std::string>{
            "mkdir -p " + ctx->gen_dir,
            in_project(ctx->unbased(procfile) + " --generate > "
                       + ctx->unbased(target))
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

        auto watched = std::set<std::string>();
        for (const auto& line: dep_lines) {
            auto based = ctx->base + line;
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

        auto dep_deps = std::vector<makefile::target::ptr>{
            std::make_shared<makefile::target>(
                "$(wildcard " + procfile + ")")
        };
        for (const auto& dir: watched)
            dep_deps.push_back(
                std::make_shared<makefile::target>(
                    "$(wildcard " + dir + ")"));

        auto variable = ctx->base.size() == 0
            ? std::string()
            : "$$(" + project::prefix_variable(ctx->base) + ")";

        auto dep_sed = std::string();
        if (variable.size() > 0)
            dep_sed += "-e 's|^|" + variable + "|' ";
        dep_sed += "-e 's|.*|" + variable + ctx->unbased(target)
                 + ": &|'";

        auto dep_commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            "(" + in_project("\"" + ctx->unbased(procfile) + "\" --deps")
                  + ") > $@.raw && sed " + dep_sed + " $@.raw > $@.tmp"
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
