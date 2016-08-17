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

        auto install_path = "$(DESTDIR)/" + ctx->prefix + "/" + ctx->hdr_dir + "/" + ctx->cmd->data();
        auto header_path = ctx->hdr_dir + "/" + ctx->cmd->data();
        
        auto global_install_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
        };

        auto short_cmd = "H\t" + ctx->cmd->data();

        auto comment = std::vector<std::string>{
            "language_h::targets() HEDAER",
            ctx->cmd->data()
        };
        
        auto install_commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            "pbashc -i " + header_path + " -o " + install_path
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
