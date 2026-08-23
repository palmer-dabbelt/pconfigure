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

#include "phony.h++"
#include "../pick_language.h++"
#include <iostream>

language_phony* language_phony::clone(void) const
{
    return new language_phony(this->list_compile_opts(),
                              this->list_link_opts());
}

bool language_phony::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::BINARY:
    case context_type::LIBRARY:
    case context_type::SOURCE:
    case context_type::TEST:
    case context_type::GENERATE:
    case context_type::HEADER:
        return false;

    case context_type::PHONY:
        return true;
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

std::vector<makefile::target::ptr>
language_phony::targets(const context::ptr& ctx) const
{
    if (ctx->type != context_type::PHONY) {
        std::cerr << "Unable to build a phony target for a "
                  << std::to_string(ctx->type)
                  << " context\n";
        std::cerr << std::to_string(ctx->cmd->debug()) << "\n";
        abort();
    }

    /* The name is rooted at the project that asked for it, the same
     * way every other target in that project's Makefile is.  Two
     * projects that both want a target called "integration" get one
     * each rather than an argument about whose rules win, and asking
     * for it from the top or from inside the project reaches the same
     * one. */
    auto name = ctx->base + ctx->cmd->data();

    /* Whatever this name is supposed to stand for gets built when
     * somebody asks for it.  A TESTDEPS is the only way to say what
     * that is: a phony target has no sources, so there's nothing else
     * for it to be made out of. */
    auto deps = std::vector<makefile::target::ptr>();
    for (const auto& dep: ctx->based_test_deps())
        deps.push_back(std::make_shared<makefile::target>(dep));

    auto comment = std::vector<std::string>{
        "language_phony::targets()",
        std::to_string(ctx->cmd->debug())
    };

    /* It stays out of "all": a name that stands for a set of things
     * to build before some tests run has no business being built by a
     * plain "make", and everything it names is built by whoever
     * builds it anyway.  Asking for it by name still works, which is
     * the point of it having one. */
    auto phony = std::make_shared<makefile::target>(
        name,
        std::string(),
        deps,
        std::vector<makefile::global_targets>{},
        std::vector<std::string>{},
        comment)->as_phony();

    auto out = std::vector<makefile::target::ptr>{phony};

    /* The tests written under it are the whole reason a project wants
     * one of these.  Each of them gets its own language the same way
     * a test under a binary does -- what builds a test is decided by
     * what the test is written in.
     *
     * The options go no further, though.  Everywhere else that
     * question is settled by asking whether the test is written in
     * the same language as the thing it tests, and here there is no
     * such thing: a phony target isn't compiled from anything, so
     * whatever COMPILEOPTS reached this context came from further up
     * and was meant for somebody else.  A test that wants options of
     * its own says so underneath itself. */
    for (const auto& child: ctx->children) {
        if (child->type != context_type::TEST) {
            std::cerr << std::to_string(child->cmd->debug()) << "\n"
                      << "  error: a PHONY target is a name and nothing"
                      << " else, so it has no "
                      << std::to_string(child->type)
                      << " to build\n"
                      << "  put that under a BINARIES, LIBRARIES, LIBEXECS"
                      << " or TESTEXECS instead\n";
            abort();
        }

        auto language = pick_language(ctx->languages, child);
        for (const auto& target: language->targets(child->without_clopts()))
            out.push_back(target);
    }

    return out;
}
