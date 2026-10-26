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

#include "asm.h++"
#include "../language_list.h++"
#include "../string_utils.h++"
#include <iostream>

/* No "-x" here, unlike C and C++, and that is what lets one compiler
 * line build both halves of a target.  Under AUTORECONFIGURE the line
 * a named source is compiled with is also the one pdeps is handed for
 * the sources behind that source's headers, so a line that said
 * "-x assembler-with-cpp" for a ".S" would assemble the ".c" found
 * behind the header it includes.  Left to itself, the compiler goes by the ending, and
 * both endings this language compiles are ones every C compiler reads
 * the same way: ".c" is C and ".S" is preprocessed assembly.
 *
 * The C++ language spells its "-x" out because ".c" behind a C++
 * target's header is meant as C++, which the ending would get wrong.
 * There is no such case here: nothing this language keeps is meant as
 * anything but what its name says. */
std::string language_asm::default_compiler_command(const context::ptr& ctx) const
{
    if (ctx->cross_compile.size() > 0)
        return ctx->cross_compile + "gcc ${CFLAGS}";

    return "${CC} ${CFLAGS}";
}

/* Only the assembly.  ".c" is C's, and a ".c" behind this target's
 * header is kept anyway, by keeps_source(), as C++ keeps it. */
bool language_asm::owns_source(const std::string& path) const
{
    return string_utils::has_extension(path, ".S");
}

language_asm* language_asm::clone(void) const
{
    return new language_asm(this->list_compile_opts(),
                            this->list_link_opts());
}

bool language_asm::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::HEADER:
    case context_type::PHONY:
        return false;

    case context_type::LIBRARY:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
        /* Not the unpreprocessed ".s": nothing about this language
         * reads one any differently from how the assembler would, and
         * the dependency scan would read its '#' comments as
         * directives. */
        return language::all_sources_match(ctx, {".c", ".S"});
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

static void install_asm(void) __attribute__((constructor));
void install_asm(void)
{
    language_list::global_add(
        std::make_shared<language_asm>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
