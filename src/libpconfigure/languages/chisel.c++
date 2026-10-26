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

#include "chisel.h++"
#include <regex>
#include "../language_list.h++"
#include "../map_util.h++"
#include "../string_utils.h++"
#include <libmakefile/exclusive_target.h++>
#include <assert.h>
#include <ctype.h>
#include <iostream>
#include <map>

/* Contains a list of Chisel targets that have already been generated,
 * to avoid the need to generate any more. */
static std::unordered_map<std::string, bool> already_generated;

/* Chisel has a number of phases, each of which can be individually
 * selected. */
enum class chisel_phase {
    COMPILE,
    RTL,
};

static const std::vector<chisel_phase> all_chisel_phases = {
    chisel_phase::COMPILE,
    chisel_phase::RTL,
};

namespace std {
    static std::string to_string(chisel_phase cmd)
    {
        switch (cmd) {
        case chisel_phase::COMPILE:
            return "COMPILE";
        case chisel_phase::RTL:
            return "RTL";
        }

        throw "Unable to convert " + to_string(static_cast<int>(cmd)) + " to string";
    }
}

/* Looks a phase up by the name a COMPILEOPTS gave it, without regard
 * to case.  A name that isn't a phase is a mistake in a Configfile,
 * so it's answered with false for the caller to refuse along with the
 * line it came from, rather than thrown: nothing here knows that line,
 * and nothing above here catches anything. */
static bool find_chisel_phase(const std::string& str, chisel_phase& out)
{
    for (const auto& phase: all_chisel_phases) {
        if (strcasecmp(str.c_str(), std::to_string(phase).c_str()) == 0) {
            out = phase;
            return true;
        }
    }

    return false;
}

/* The phases' names, the way a refusal lists them for whoever has to
 * pick one: lower case, since that is how they're usually written in
 * a "-W<phase>," and the lookup doesn't mind. */
static std::string chisel_phase_names(void)
{
    auto names = std::vector<std::string>();
    for (const auto& phase: all_chisel_phases) {
        auto name = std::to_string(phase);
        for (auto& c: name)
            c = tolower(c);
        names.push_back(name);
    }
    return string_utils::join(names, ", ");
}

/* A class to hold the various phase arguments. */
class phase_argument {
private:
    const std::string _key;
    const std::string _value;
    
public:
    phase_argument(const std::string& to_parse)
        : _key(to_parse.substr(1, to_parse.find(',')-1)),
          _value(to_parse.substr(to_parse.find(',')+1))
        {}

public:
    const std::string& key  (void) const { return _key  ; }
    const std::string& value(void) const { return _value; }
};

/* The actual Chisel class implementation lives here, though it's not
 * really meant to be much since it's simply  */
language_chisel* language_chisel::clone(void) const
{
    return new language_chisel(this->list_compile_opts(),
                               this->list_link_opts());
}

bool language_chisel::can_process(const context::ptr& ctx) const
{
    if (language::all_sources_match(ctx, {".scala", ".v"})) {
        return true;
    }

    return false;
}

std::vector<makefile::target::ptr>
language_chisel::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    /* Every refusal below is about a Configfile line, so each starts
     * by naming one.  The options don't remember which line wrote
     * them, so it's the line of the target they landed on, and the
     * refusal quotes the option itself so it can be found from there.
     * The context tree isn't printed: it's pconfigure's business, and
     * the line already says everything in it that the reader wrote. */
    auto refuse = [&](void) -> std::ostream&
        {
            std::cerr << std::to_string(ctx->cmd->debug()) << "\n";
            return std::cerr;
        };

    /* What chisel makes is a Verilog file, copied into the library
     * directory under the target's name, so a LIBRARIES is the only
     * thing it can build.  A BINARIES is the likely mistake, since
     * that's what a Scala program would be anywhere else, and the
     * name it was given is the one to suggest. */
    if (ctx->type != context_type::LIBRARY) {
        refuse() << "  error: chisel can't build a "
                 << std::to_string(ctx->cmd->type())
                 << ": what it makes from Scala is a Verilog file, which is"
                 << " a LIBRARIES\n"
                 << "  write 'LIBRARIES += " << ctx->cmd->data() << ".v'"
                 << " instead\n";
        abort();
    }

    /* There can't be any link-time options for Chisel projects
     * because there really isn't an actual link time: the library is
     * a copy of what the elaborator wrote.  Quietly dropping one would
     * leave whoever wrote it believing it did something. */
    for (const auto& opt: this->link_opts(ctx)) {
        refuse() << "  error: chisel libraries aren't linked, so the"
                 << " LINKOPTS '" << opt << "' has nothing to apply to\n"
                 << "  remove that LINKOPTS\n";
        abort();
    }

    /* Walk through and parse the compile-time options, producing the
     * argument lists that should be passed to each phase of
     * compilation. */
    std::multimap<chisel_phase, phase_argument> phase_args;
    auto target_phase = chisel_phase::RTL;
    for (const auto& opt: this->compile_opts(ctx)) {
        if (std::regex_match(opt, std::regex("-Wdriver,.*"))) {
            /* "-Wdriver,*" is sent to all phases. */
            auto arg = phase_argument(opt.substr(9));
            for (const auto& phase: all_chisel_phases)
                phase_args.insert({phase, arg});

            if (arg.key() == "target"
                && find_chisel_phase(arg.value(), target_phase) == false) {
                refuse() << "  error: the COMPILEOPTS '" << opt << "' makes"
                         << " the chisel phase '" << arg.value() << "' the"
                         << " target, and chisel has no phase by that name\n"
                         << "  write '-Wdriver,-target,<phase>' with one of: "
                         << chisel_phase_names() << "\n";
                abort();
            }
        } else if (std::regex_match(opt, std::regex("-W.*,.*"))) {
            /* "-W*,*,*" is sent to only a single phase, whose name is
             * everything between the "-W" and the first comma. */
            auto comma = opt.find(',');
            auto name = opt.substr(2, comma-2);
            auto phase = chisel_phase::RTL;
            if (find_chisel_phase(name, phase) == false) {
                refuse() << "  error: the COMPILEOPTS '" << opt << "' is for"
                         << " the chisel phase '" << name << "', and chisel"
                         << " has no phase by that name\n"
                         << "  write '-W<phase>,<arg>' with one of: "
                         << chisel_phase_names()
                         << ", or '-Wdriver,<arg>' for all of them\n";
                abort();
            }
            phase_args.insert({phase, opt.substr(comma+1)});
        } else {
            refuse() << "  error: chisel can't use the COMPILEOPTS '" << opt
                     << "': its options go to one of its phases rather than"
                     << " to a compiler\n"
                     << "  write '-W<phase>,<arg>' with one of: "
                     << chisel_phase_names()
                     << ", or '-Wdriver,<arg>' for all of them\n";
            abort();
        }
    }

    /* Begin emitting the code for the various phases of the Chisel to
     * mask build process.  First we find a target build directory
     * that: depends on only the sources, not the binary/library,
     * which allows us to ensure that all these steps are only run
     * once. */
    auto obj_dir = ctx->obj_dir + "/" + ctx->in_source_tree(ctx->src_dir);

    /* The whole point of this is to go and generate some targets. */
    auto all_targets = std::vector<makefile::target::ptr>();
    auto add_to_all = [&](makefile::target::ptr i)
        {
            all_targets.push_back(i);
            return i;
        };

    /* This target builds the source code into a directory somewhere
     * in the temporary directory.  Note that this doesn't actually
     * depend on any flags, and builds everything in the source
     * directory that's listed. */
    auto target_scalac = add_to_all([&]() -> makefile::target::ptr
        {
            auto workdir = obj_dir + "/scalac";
            auto stampdir = workdir + "/" + ctx->bin_dir + "/" + ctx->cmd->data();

            auto sources = vector_util::map(
                ctx->children,
                [&](const context::ptr& child) -> makefile::target::ptr
                {
                    auto srcpath = ctx->src_dir + "/" + child->cmd->data();
                    return std::make_shared<makefile::target>(srcpath);
                });

            auto source_strings = vector_util::map(
                sources,
                [&](const makefile::target::ptr& source) -> std::string
                {
                    return source->name();
                });

            auto global_targets = std::vector<makefile::global_targets>{
                makefile::global_targets::CLEAN,
            };

            std::vector<std::string> commands = {
                "mkdir -p " + workdir,
                "mkdir -p " + stampdir,
                "scalac "
                  + std::string("-make:changed ")
                  + std::string("-d ") + workdir + " "
                  + std::string("-classpath .:/usr/lib/libchisel.jar ")
                  + string_utils::join(source_strings, " "),
                "date > " + stampdir + "/stamp"
            };

            std::vector<std::string> comments = {
                "language_chisel::targets()/scalac " + ctx->cmd->data()
            };

            return std::make_shared<makefile::exclusive_target>(
                workdir,
                stampdir + "/stamp",
                "CH-SC\t" + ctx->cmd->data(),
                sources,
                global_targets,
                commands,
                comments
                );
        }());

    /* Elaborates the Scala code into a Verilog file. */
    auto target_rtl = add_to_all([&]() -> makefile::target::ptr
        {
            auto phase = chisel_phase::RTL;
            auto workdir = obj_dir + "/scalac";

            std::vector<makefile::target::ptr> sources = {
                target_scalac
            };

            auto top = std::string("Main");
            auto top_args = std::vector<std::string>();
            for (const auto& pair: map_util::equal_range(phase_args, phase)) {
                if (pair.second.key() == "top")
                    top = pair.second.value();
                if (pair.second.key() == "topArg")
                    top_args.push_back(pair.second.value());
            }

            auto target_dir = obj_dir + "/chisel/" + string_utils::hash(top_args);

            auto global_targets = std::vector<makefile::global_targets>{
                makefile::global_targets::CLEAN,
            };

            std::vector<std::string> commands = {
                "mkdir -p " + workdir,
                "scala " + std::string("")
                  + "-classpath /usr/lib/libchisel.jar:" + workdir + " "
                  + top + std::string(" ")
                  + "--targetDir " + target_dir + " "
                  + std::string("--backend v")
            };

            std::vector<std::string> comments = {
                "language_chisel::targets()/rtl " + ctx->cmd->data()
            };

            return std::make_shared<makefile::target>(
                target_dir + "/" + top + ".v",
                "CH-RTL\t" + ctx->cmd->data(),
                sources,
                global_targets,
                commands,
                comments
                );
        }());

    if (target_phase == chisel_phase::RTL)
        goto emit_target;

emit_target:
    /* Copy the elaborated Verilog file to the bin directory. */
    auto target_copy = add_to_all([&]() -> makefile::target::ptr
        {
            auto last_target = all_targets[all_targets.size()-1];

            std::vector<makefile::target::ptr> sources = {
                last_target
            };

            auto dest = ctx->lib_dir + "/" + ctx->cmd->data();

            auto global_targets = std::vector<makefile::global_targets>{
                makefile::global_targets::ALL,
                makefile::global_targets::CLEAN,
            };

            std::vector<std::string> commands = {
                "mkdir -p $(dir " + dest + ")",
                "cp " + sources[0]->name() + " " + dest
            };

            std::vector<std::string> comments = {
                "language_chisel::targets()/copy " + ctx->cmd->data()
            };

            return std::make_shared<makefile::target>(
                dest,
                "CH-CP\t" + ctx->cmd->data(),
                sources,
                global_targets,
                commands,
                comments
                );
        }());

    /* Filter the list of targets so only the new ones get emitted. */
    auto new_targets = vector_util::filter(
        all_targets,
        [&](const makefile::target::ptr& target) -> bool
        { return map_util::true_map(already_generated, target->name()) == false; }
        );

    for (const auto& target: new_targets)
        already_generated.insert({target->name(), true});

    return new_targets;
}

static void install_chisel(void) __attribute__((constructor));
void install_chisel(void)
{
    language_list::global_add(
        std::make_shared<language_chisel>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
