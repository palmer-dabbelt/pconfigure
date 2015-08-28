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
#include "../language_list.h++"
#include "../map_util.h++"
#include "../string_utils.h++"
#include <libmakefile/exclusive_target.h++>
#include <assert.h>
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

static chisel_phase check_chisel_phase(const std::string& str)
{
    for (const auto& ctx: all_chisel_phases)
        if (strcasecmp(str.c_str(), std::to_string(ctx).c_str()) == 0)
            return ctx;

    throw "Unable to process " + str + " chisel_phase";
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
    return new language_chisel();
}

bool language_chisel::can_process(const context::ptr& ctx) const
{
    if (language::all_sources_match(ctx,
                                    {std::regex(".*\\.scala"),
                                     std::regex(".*\\.v")})) {
        return true;
    }

    return false;
}

std::vector<makefile::target::ptr>
language_chisel::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    /* Generating Chisel output is pretty much the same regardless of
     * the target type, there's just a slightly */
    auto target_path = [&](void)
        {
            switch (ctx->type) {
            case context_type::LIBRARY:
            return ctx->lib_dir + "/" + ctx->cmd->data();

            case context_type::DEFAULT:
            case context_type::BINARY:
            case context_type::GENERATE:
            case context_type::SOURCE:
            case context_type::TEST:
            std::cerr << "Unimplemented context type: "
            << std::to_string(ctx->type)
            << "\n";
            std::cerr << ctx->as_tree_string("  ");
            abort();
            break;
            }

            std::cerr << "context type not in switch\n";
            abort();
        }();

    /* There can't be any link-time options for Chisel projects
     * because there really isn't an actual link time, so I just fail
     * here if anything is actually provided. */
    if (this->link_opts(ctx).size() != 0) {
        std::cerr << "Chisel projects can't have link-time arguments\n";
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

            try {
                if (arg.key() == "target")
                    target_phase = check_chisel_phase(arg.value());
            } catch(...) {
                std::cerr << "Unknown target name " << arg.value() << "\n";
                std::cerr << "  This probably came from a -Wdriver,-target\n";
                std::cerr << ctx->as_tree_string("  ");
                abort();
            }
        } else if (std::regex_match(opt, std::regex("-W.*,.*"))) {
            /* "-W*,*,*" is sent to only a single phase. */
            auto comma = opt.find(',');
            auto phase = check_chisel_phase(opt.substr(2, comma-1));
            phase_args.insert({phase, opt.substr(comma+1)});
        } else {
            std::cerr << "ERROR: unknown Chisel argument " << opt << "\n";
            std::cerr << ctx->as_tree_string("  ");
            abort();
        }
    }

    /* Begin emitting the code for the various phases of the Chisel to
     * mask build process.  First we find a target build directory
     * that: depends on only the sources, not the binary/library,
     * which allows us to ensure that all these steps are only run
     * once. */
    auto obj_dir = ctx->obj_dir + "/" + ctx->src_dir;

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
    language_list::global_add(std::make_shared<language_chisel>());
}
