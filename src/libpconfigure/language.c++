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

#include "language.h++"
#include "project.h++"
#include "string_utils.h++"
#include <errno.h>
#include <iostream>
#include <string.h>
#include <unistd.h>

language::language(const std::vector<std::string>& compile_opts,
                   const std::vector<std::string>& link_opts)
: _compile_opts(compile_opts),
  _link_opts(link_opts)
{
}

void language::add_compileopt(const std::string& data)
{
    _compile_opts.push_back(data);
}

void language::add_linkopt(const std::string& data)
{
    _link_opts.push_back(data);
}

bool language::all_sources_match(const context::ptr& ctx,
                                 const std::vector<std::string>& extensions)
{
    /* A phony target is a name and isn't built out of anything, so no
     * language that decides by looking at sources gets to claim one:
     * with no sources at all, every list of extensions matches and
     * every such language would say yes. */
    if (ctx->type == context_type::PHONY)
        return false;

    for (const auto& child: ctx->children) {
        switch (child->type) {
        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::LIBRARY:
        case context_type::BINARY:
        case context_type::TEST:
        case context_type::PHONY:
            break;

        case context_type::HEADER:
        case context_type::SOURCE:
        {
            auto matched = false;
            for (const auto& extension: extensions)
                if (string_utils::has_extension(child->cmd->data(), extension))
                    matched = true;

            if (matched == false)
                return false;

            break;
        }
        }
    }

    return true;
}

/* make never reruns a rule because its recipe changed, only because a
 * prerequisite is newer than the target.  A C object follows its
 * options because they are hashed into the object's path, so a changed
 * flag is a different target; but plenty of outputs have one fixed
 * name -- bin/<tool>, the compiled copy of a test, include/<hdr>,
 * lib/pkgconfig/<name>.pc -- and a reconfigure that changed an option
 * or pointed the target at a different SOURCES left the old output in
 * place: the file the rule now names already existed and was older
 * than what had been built from the other one.
 *
 * This is the link-inputs file language_cxx::link_objects() writes for
 * a link, for the same reason and in the same way: written at
 * configure time, rewritten only when what it says changes, so that a
 * reconfigure which changes nothing rebuilds nothing, and written back
 * by the Makefile if the object directory it sits in is thrown away.
 * What it holds is the recipe itself rather than a hash of it, since
 * the recipe is every input there is -- the source, the options and
 * the output -- and a file that says how the target was last built is
 * one somebody can read.  A recipe that names its sources outright
 * rather than through "$^" is one this file being a prerequisite puts
 * nothing on the command line of.
 *
 * It sits in the object directory under the output's own name, with
 * ".recipe-inputs" on the end: obj/bin/<tool>..., obj/include/<hdr>...
 * An output that is already in the object directory, like the compiled
 * copy of a test, gets its record beside it rather than under a second
 * "obj"; a directory named after the output can't be used there, since
 * the output itself is the file of that name.
 *
 * And it has the run that wrote it on the very end, the way a
 * Makefile.<path> or a deps-context-* does, for the reason
 * project::base_suffix() gives: a subproject is configured from the
 * top and from inside itself, and each of those spells the recipe from
 * where it stands -- "sub/obj/..." from one, "obj/..." from the other.
 * A record both shared would hold whichever ran last, so every
 * configure of one would rebuild the output (and run the test again)
 * in the other's next make, with nothing about either having changed.
 * The top of a run gets no suffix at all, so a project configured only
 * on its own keeps the name it always had. */
std::string
language::recipe_record_path(const context::ptr& ctx,
                             const std::string& output)
{
    auto name = file_utils::inside(output, ctx->obj_dir)
        ? output.substr(ctx->obj_dir.size() + 1)
        : ctx->unbased(output);
    return ctx->obj_dir + "/" + name + ".recipe-inputs"
        + project::base_suffix(ctx->base);
}

makefile::target::ptr
language::recipe_record(const context::ptr& ctx,
                        const std::string& output,
                        const std::vector<std::string>& commands)
{
    auto recipe_path = recipe_record_path(ctx, output);
    auto recipe = std::string();
    for (const auto& line: commands)
        recipe += line + "\n";

    /* A record that wasn't there before is new without anything it
     * records having changed: this is the first configure since the
     * output was made by something that kept no record -- a
     * bootstrap.sh that compiles its own tool, or a pconfigure from
     * before this file existed.  Left with the time it was written, it
     * would be newer than that output and rebuild it on the next make
     * for nothing; a tool rebuilt that way is then a new tool, and a
     * tree that bootstraps it reconfigures a second time.  So a first
     * record takes the output's time instead.  Only a record that was
     * there and said something else is a reason to rebuild, which is
     * the case all of this is for. */
    auto first_record = access(recipe_path.c_str(), F_OK) != 0;
    auto wrote = file_utils::write_configure_output(recipe_path, recipe);
    if (wrote == true && first_record == true)
        wrote = file_utils::no_newer_than(recipe_path, output);

    if (wrote == false) {
        std::cerr << "can't write '" << recipe_path << "': "
                  << strerror(errno) << "\n"
                  << "  this is where the command that builds '"
                  << ctx->cmd->data() << "' is written down, which is\n"
                  << "  how a change to its options or its SOURCES"
                  << " gets it built again\n";
        abort();
    }

    return std::make_shared<makefile::target>(recipe_path);
}
