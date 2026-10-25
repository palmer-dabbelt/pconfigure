/*
 * Copyright (C) 2016 Palmer Dabbelt
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

#include "implicit_h.h++"
#include <libmakefile/self_path.h++>
#include "../language_list.h++"
#include <assert.h>
#include <iostream>

language_implicit_h* language_implicit_h::clone(void) const
{
    return new language_implicit_h(this->list_compile_opts(),
                                   this->list_link_opts());
}

bool language_implicit_h::can_process(const context::ptr& ctx) const
{
    if (ctx->type != context_type::HEADER)
        return false;

    if (ctx->children.size() > 0)
        return false;

    return true;
}

std::vector<makefile::target::ptr>
language_implicit_h::targets(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::LIBRARY:
    case context_type::GENERATE:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
    case context_type::PHONY:
        std::cerr << "Unimplemented h context type "
                  << std::to_string(ctx->type)
                  << "\n";
        abort();
        return {};

    case context_type::HEADER:
    {
        if (ctx->children.size() > 0) {
            std::cerr << "language_implicit_h::targets() with children\n";
            abort();
        }

        auto install_path = "$(DESTDIR)" + ctx->installed(ctx->hdr_dir) + "/" + ctx->cmd->data();

        /* A header with nothing under it is one somebody wrote, so it
         * is read out of the source tree rather than out of the build
         * directory: with a "--srcpath" or a SRCPATH those are two
         * different places, and hdr_dir is spelled from where
         * pconfigure was run.  This is the same directory the C scan
         * puts first on the include path, so the header a compile
         * found is the header that gets installed.  Without a srcpath
         * src_path is the base and this is hdr_dir again. */
        auto header_path = ctx->src_path + ctx->unbased(ctx->hdr_dir)
            + "/" + ctx->cmd->data();

        /* On "uninstall" as well as "install", for the reason
         * languages/bash.c++ gives: a rule that only installs is a
         * header "make uninstall" leaves behind under the prefix. */
        auto global_install_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
            makefile::global_targets::UNINSTALL,
        };

        auto short_cmd = "H\t" + ctx->cmd->data();

        auto comment = std::vector<std::string>{
            "language_h::targets() HEDAER",
            ctx->cmd->data()
        };
        
        /* phc, the same program the explicit "h" language installs a
         * header with.  This used to be pbashc, which is the compiler
         * for bash scripts and has no business reading a C header:
         * every "#include" in one is a directive to pbashc rather
         * than a line of the file, so what got installed was the
         * header with all of its includes taken out of it.
         *
         * phc is a "cp", and copies the mode along with the header,
         * so the installed one is then given the mode "install -m
         * 644" would, for the reason languages/bash.c++ gives: a
         * header written under "umask 077" otherwise goes in under
         * the prefix readable by nobody but whoever wrote it.  It's
         * done here rather than in phc because phc makes the build
         * tree's copies of headers too, and those are the builder's
         * to keep at whatever mode their umask gave them. */
        auto install_commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            ctx->phc + " -i " + header_path + " -o " + install_path,
            "chmod 0644 " + install_path
        };

        auto header_target = std::make_shared<makefile::target>(header_path);
        
        auto install_target = std::make_shared<makefile::target>(install_path,
                                                                short_cmd,
                                                                std::vector<makefile::target::ptr>{header_target},                                       
                                                                global_install_targets,                                                               
                                                                install_commands,
                                                                comment);

        return {install_target};

    }
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();

}

static void install_implicit_h(void) __attribute__((constructor));
void install_implicit_h(void)
{
    language_list::global_add(
        std::make_shared<language_implicit_h>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
