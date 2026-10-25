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

#include "pkgconfig.h++"
#include "../commands.h++"
#include "../language_list.h++"
#include "../string_utils.h++"
#include <assert.h>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* Where this project sits, spelled from the root of the filesystem.
 *
 * The pkg-config file that gets written for the build tree has to say
 * where things are in a way that means the same thing to everybody
 * who reads it, and the projects reading it are at all sorts of
 * depths.  A relative answer would be re-rooted a second time by
 * whoever consumed it. */
static std::string absolute_base(const std::string& base)
{
    auto buffer = std::vector<char>(4096);
    while (getcwd(&buffer[0], buffer.size()) == NULL) {
        if (errno != ERANGE) {
            perror("Unable to find the working directory");
            abort();
        }
        buffer.resize(buffer.size() * 2);
    }

    auto out = std::string(&buffer[0]);
    if (base.size() > 0)
        out += "/" + base.substr(0, base.size() - 1);
    return out;
}

/* Text to be pasted in as the replacement half of the
 * 's^pattern^replacement^g' the .pc is run through, inside the
 * single quotes that hand it to sed.
 *
 * Every character sed gives a meaning to there has to be spelled so
 * it means itself: a '&' is "whatever matched", so a checkout under
 * "R&D" used to come out naming ".../R@@pconfigure_prefix@@D"; a '^'
 * is the delimiter, so one under "v1^2" ended the replacement early
 * and sed refused the whole expression, leaving no .pc at all; and a
 * backslash escapes whatever follows it.  The single quotes are the
 * shell's, and a quote in the text has to step outside them to be
 * written at all. */
static std::string sed_replacement(const std::string& text)
{
    auto out = std::string();
    for (const auto& c: text) {
        switch (c) {
        case '\\':
        case '&':
        case '^':
            out += '\\';
            out += c;
            break;
        case '\'':
            out += "'\\''";
            break;
        default:
            out += c;
            break;
        }
    }
    return out;
}

language_pkgconfig* language_pkgconfig::clone(void) const
{
    return new language_pkgconfig(this->list_compile_opts(),
                                  this->list_link_opts());
}

bool language_pkgconfig::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::HEADER:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
    case context_type::PHONY:
        return false;

    case context_type::LIBRARY:
        return language::all_sources_match(ctx, {".pc"});
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

std::vector<makefile::target::ptr>
language_pkgconfig::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::BINARY:
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

    case context_type::LIBRARY:
    {
        /* BASH-like languages are designed to be super simple: since
         * all they do is just link all the sources together at the
         * end, there's no need for any internal targets at all. */
        auto target = ctx->lib_dir + "/" + ctx->cmd->data();

        auto short_cmd = "PKGCFG\t" + ctx->cmd->data();

        /* A .pc is one template run through sed, so there is exactly
         * one file for it to be made out of.  The "-S" sed scripts
         * below are prerequisites too, but they are kept on a list of
         * their own: the recipe used to "cat" whatever came first on a
         * shared list, which made a lone "-S" script the template and
         * read past the end of an empty list when there was nothing
         * at all. */
        context::ptr template_ctx = NULL;
        for (const auto& child: ctx->children) {
            if (child->type != context_type::SOURCE)
                continue;

            /* A second SOURCES used to be made a prerequisite and then
             * never read, so editing it rebuilt the .pc and nothing in
             * it ever reached the output.  This is the same refusal a
             * BASH target makes, less the advice about including one
             * file from the other: there is no "#include" in a .pc, so
             * the two have to become one file. */
            if (template_ctx != NULL) {
                auto first_path = template_ctx->src_dir + "/"
                    + template_ctx->cmd->data();
                auto path = child->src_dir + "/" + child->cmd->data();
                auto where = template_ctx->cmd->debug()->filename() + ":"
                    + std::to_string(template_ctx->cmd->debug()->line_number());

                std::cerr << std::to_string(child->cmd->debug()) << "\n";
                if (path == first_path) {
                    std::cerr << "  error: '" << child->cmd->data()
                              << "' is already the SOURCES of '"
                              << ctx->cmd->data() << "', from "
                              << where << "\n"
                              << "  delete this line\n";
                    abort();
                }

                std::cerr << "  error: '" << ctx->cmd->data()
                          << "' is one pkg-config file made from one"
                          << " template, and it already has '"
                          << template_ctx->cmd->data() << "' from "
                          << where << "\n"
                          << "  move what is in " << child->cmd->data()
                          << " into " << template_ctx->cmd->data()
                          << " instead of a second SOURCES, or give "
                          << child->cmd->data() << " a LIBRARIES of its"
                          << " own\n";
                abort();
            }

            template_ctx = child;
        }

        auto sources = std::vector<makefile::target::ptr>();
        if (template_ctx != NULL)
            sources.push_back(std::make_shared<makefile::target>(
                template_ctx->src_dir + "/" + template_ctx->cmd->data()));

        /* pkg-config can take an indirect sed reference, which
         * involves running a sed command that is stored in a file.
         * Thus, the result of the pkg-config file that is output
         * depends on the contents of that file (which is often
         * generated by pconfigure somewhere else, but that doesn't
         * matter). */
        /* A "-S" names a file that holds a sed command, which is
         * usually generated somewhere else in the same project -- so
         * it's a source of this .pc file, and it's relative to
         * whoever wrote it rather than to where pconfigure ran. */
        auto sed_file = [&](const std::string& str) {
            auto path = str.substr(2);
            if (path.size() > 0 && path[0] != '/')
                return ctx->base + path;
            return path;
        };

        auto sed_scripts = std::vector<makefile::target::ptr>();
        for (const auto& str: this->clopts(ctx))
            if (strncmp(str.c_str(), "-S", 2) == 0)
                sed_scripts.push_back(
                    std::make_shared<makefile::target>(sed_file(str)));

        auto prerequisites = sources + sed_scripts;

        auto filename = ctx->cmd->debug()->filename();
        auto lineno = ctx->cmd->debug()->line_number();

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        /* Each option is, as the manual puts it, passed to sed as an
         * argument: one argument, holding exactly what was written.
         * That takes quoting, because a sed expression is allowed any
         * character at all and a .pc file is mostly free text -- a
         * Description with an apostrophe in it, or a Version with a
         * space in it, is not doing anything unusual.
         *
         * The same command is read by two different things, though.
         * make expands a '$' in a recipe before the shell sees it,
         * which would turn the '$' anchoring an expression to the end
         * of a line into whatever some make variable held, so the
         * recipe spells it '$$'.  The build-tree copy is also built
         * here by pconfigure, through a shell with no make in front
         * of it, where a '$$' would be a process ID -- so whoever
         * runs the command says which of the two it is for.
         *
         * A "-S" file is read with backticks inside double quotes
         * rather than "$(cat ...)" for the same reason: it contains
         * no '$' for make to get at, so both readers see the same
         * thing.  The double quotes are what keep its contents one
         * argument; without them the shell split a script at every
         * space, and "s/@@VERSION@@/1.0 beta/" became an unterminated
         * expression and a file called "beta/".  The shell strips
         * the trailing newline the file almost certainly ends with,
         * and any newlines left in the middle separate commands just
         * as they would in a sed script.
         *
         * An option that starts with a backtick is still handed over
         * as written: it is a command for the shell to run, and its
         * output being split into words is what it is for.
         *
         * With no template there's no .pc to write.  The project
         * has already warned that this target has nothing to build,
         * which is all STRICT lets it be, so the Makefile still comes
         * out -- but the rule for the .pc fails when make reaches it,
         * naming the line, rather than writing out an empty file that
         * some consumer's pkg-config would take at its word. */
        auto build = [&](const std::string& prefix, bool for_make,
                         const std::string& output) {
            auto argument = [&](const std::string& str) {
                if (for_make)
                    return string_utils::quoted(string_utils::unexpanded(str));
                return string_utils::quoted(str);
            };

            auto command = std::string();
            if (sources.size() == 0)
                return "echo '" + filename + ":" + std::to_string(lineno)
                    + ": " + ctx->cmd->data() + " has no SOURCES to be"
                    + " made from' >&2; exit 1";

            command += "cat " + sources[0]->name();
            auto replace = [&](const std::string& name,
                               const std::string& value) {
                return " | sed 's^@@pconfigure_" + name + "@@^"
                    + sed_replacement(value) + "^g'";
            };
            command += replace("prefix", prefix);
            command += replace("libdir", ctx->unbased(ctx->lib_dir));
            command += replace("hdrdir", ctx->unbased(ctx->hdr_dir));
            for (const auto& str: this->clopts(ctx)) {
                if (strncmp(str.c_str(), "-S", 2) == 0)
                    command += " | sed \"`cat " + argument(sed_file(str)) + "`\"";
                else if (strncmp(str.c_str(), "`", 1) == 0)
                    command += " | sed " + str;
                else
                    command += " | sed " + argument(str);
            }

            command += "> " + output;
            return command;
        };

        auto commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            build(ctx->prefix, true, target)
        };

        auto comment = std::vector<std::string>{
            "language_pkgconfig::targets()",
            filename + ":" + std::to_string(lineno)
        };

        auto bin_target = std::make_shared<makefile::target>(target,
                                                             short_cmd,
                                                             prerequisites,
                                                             global_targets,
                                                             commands,
                                                             comment);

        /* The one above describes where this library will be once
         * it's installed.  Another project in this build needs to
         * link against it now, where it actually is, so there's a
         * second copy that says that -- and it gets built while
         * pconfigure is still running, because the Configfile that
         * wants to know about it is being read right now. */
        auto pkgconfig_dir = ctx->obj_dir + "/pkgconfig";
        auto basename = ctx->cmd->data().substr(
            ctx->cmd->data().find_last_of("/") + 1);
        auto build_path = pkgconfig_dir + "/" + basename;

        auto build_target = std::make_shared<makefile::target>(
            build_path,
            short_cmd,
            prerequisites,
            std::vector<makefile::global_targets>{
                makefile::global_targets::ALL,
                makefile::global_targets::CLEAN,
            },
            std::vector<std::string>{
                /* Spelled out rather than "$(dir $@)", to match the
                 * copy pconfigure writes itself below, where there's
                 * no make around to say what that means. */
                "mkdir -p " + pkgconfig_dir,
                build(absolute_base(ctx->base), true, build_path)
            },
            comment);

        add_pkgconfig_path(pkgconfig_dir);

        /* The built copy is what a consumer's ppkg-config backtick
         * gets answered out of, so it is an input to the configure
         * step: named here so that its changing is a reason to
         * reconfigure rather than a change the build keeps quiet
         * about. */
        add_pkgconfig_dep(build_path);

        /* The copy is rewritten on every configure, not just when
         * there isn't one yet.  One left over from the last run was
         * written out of whatever the .pc and its "-S" scripts said
         * then, and rerunning pconfigure after editing one of them
         * is exactly how somebody asks for the new answer: believing
         * the old copy configured the consumer without the edit and
         * left a second configure to notice it.  Comparing times
         * instead would miss an edit made in the same second as the
         * last configure, and running a few seds costs nothing next
         * to the rest of a configure.
         *
         * Without a template the commands only say so and fail, and
         * the project has already said that once here.  Anything
         * it's built from that isn't there yet will be by the time
         * make runs, so this is worth trying and not worth failing
         * over -- and in that case whatever copy is already there is
         * the best answer there is, so it's left alone.  The new copy
         * is written beside the old one and only moved over it once
         * it's complete, so a sed that fails part way through doesn't
         * replace a working copy with half of one. */
        auto have_sources = sources.size() > 0;
        for (const auto& source: prerequisites)
            if (access(source->name().c_str(), R_OK) != 0)
                have_sources = false;

        if (have_sources == true) {
            /* The same two commands as the target's, but spelled for
             * a shell rather than for make: see build() above. */
            auto temp_path = build_path + ".pconfigure-tmp";
            auto mkdir_cmd = "mkdir -p " + pkgconfig_dir;
            auto write_cmd = build(absolute_base(ctx->base), false, temp_path);
            if (system(mkdir_cmd.c_str()) == 0
                && system(write_cmd.c_str()) == 0)
                rename(temp_path.c_str(), build_path.c_str());
            else
                unlink(temp_path.c_str());
        }

        auto install_path = "$(DESTDIR)" + ctx->installed(target);

        auto install_commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            build(ctx->prefix, true, install_path)
        };

        auto install_global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
            makefile::global_targets::UNINSTALL,
        };

        auto ins_target = std::make_shared<makefile::target>(install_path,
                                                             short_cmd,
                                                             prerequisites,
                                                             install_global_targets,
                                                             install_commands,
                                                             comment);

        return {bin_target, build_target, ins_target};
        break;
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}

static void install_pkgconfig(void) __attribute__((constructor));
void install_pkgconfig(void)
{
    language_list::global_add(
        std::make_shared<language_pkgconfig>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
