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

#include "build_system.h++"
#include "build_systems/buildroot.h++"
#include "build_systems/kconfig.h++"
#include "build_systems/pconfigure.h++"
#include "file_utils.h++"
#include <iostream>

build_system::build_system(const std::string& name)
: _name(name),
  _base(),
  _context(NULL),
  _configureopts(),
  _makeopts(),
  _makeopt_from_option(),
  _taking_configureopt(false),
  _subproject_targets()
{
}

void build_system::add_configureopt(const std::string& opt)
{
    _configureopts.push_back(opt);

    _taking_configureopt = true;
    take_configureopt(opt);
    _taking_configureopt = false;
}

void build_system::add_makeopt(const std::string& opt)
{
    if (run_by_make() == false) {
        std::cerr << "MAKEOPS doesn't apply to a " << name()
                  << " subproject: '" << opt << "'\n"
                  << "  there is no make being run here for a variable to"
                  << " go on the command line of\n";
        abort();
    }

    /* A variable is a name and a value.  Without the '=' this is a
     * word that make would take for a goal, which is a different
     * thing entirely and one that would go quietly wrong: the tree
     * would be asked to build a target nobody meant. */
    if (opt.find('=') == std::string::npos) {
        std::cerr << name() << ": MAKEOPS '" << opt << "' has no value:"
                  << " it should look like 'MAKEOPS += ARCH=arm64'\n";
        abort();
    }

    _makeopts.push_back(opt);
    _makeopt_from_option.push_back(_taking_configureopt);
}

void build_system::add_subproject_target(const std::string& path)
{
    /* A named output is a file in one tree's output directory, so it
     * needs a tree.  A CONFIGUREOPTS written after a BUILD_SYSTEMS
     * means "every subproject built this way", which is a sentence
     * that has no ending here: there is no one directory for the file
     * to be in. */
    if (base().size() == 0) {
        std::cerr << "SUBPROJECT_TARGETS needs a SUBPROJECTS above it: '"
                  << path << "'\n"
                  << "  it names a file that one vendored tree builds,"
                  << " so it has to say which tree\n";
        abort();
    }

    if (build_stamp().size() == 0) {
        std::cerr << "SUBPROJECT_TARGETS doesn't apply to a " << name()
                  << " subproject: '" << path << "'\n"
                  << "  nothing here says the tree has been built, so there"
                  << " is nothing for this to wait for\n";
        abort();
    }

    /* The path is named relative to where the tree builds, and a path
     * that climbs out of there names something this tree didn't
     * make.  A rule that claims otherwise would tell make the file
     * gets built by a sub-make that never touches it. */
    auto normalized = file_utils::normalize_path(path);
    if (normalized.compare(0, 3, "../") == 0
        || (normalized.size() > 0 && normalized[0] == '/')) {
        std::cerr << name() << ": SUBPROJECT_TARGETS '" << path << "' has to"
                  << " name something the tree builds,\n"
                  << "  so it's relative to '" << build_dir() << "' and can't"
                  << " reach outside it\n";
        abort();
    }

    for (const auto& already: _subproject_targets)
        if (already == normalized)
            return;

    _subproject_targets.push_back(normalized);
}

bool build_system::produces(const std::string& path) const
{
    for (const auto& target: _subproject_targets)
        if (build_dir() + "/" + target == path)
            return true;

    return false;
}

std::string build_system::makeopt_flags(void) const
{
    /* One variable is one argument, however many spaces are in its
     * value: "KCFLAGS=-O2 -g" is a thing people write and mean, and
     * what the shell does with it unquoted is hand make a variable
     * called KCFLAGS worth "-O2" and then a "-g" that make reads as a
     * flag of its own.
     *
     * This doesn't take the value apart, which is the thing that must
     * not happen: make expands the Makefile before the shell ever
     * sees the line, so "$(abspath x)" still means what it says and
     * still gets to have a space in the path it comes back with. */
    auto quoted = [](const std::string& in) {
        auto out = std::string("'");
        for (const auto& c: in) {
            if (c == '\'')
                out += "'\\''";
            else
                out += c;
        }
        return out + "'";
    };

    auto out = std::string();
    for (const auto& opt: _makeopts)
        out += " " + quoted(opt);
    return out;
}

std::vector<makefile::target::ptr>
build_system::targets(const std::vector<ptr>& peers) const
{
    auto out = vendored_targets(peers);

    /* Every named output hangs off the one stamp that says the tree
     * has been built, which is the only thing here that runs the
     * tree's own build system.  That's what keeps a "make -j" that
     * wants three of them from starting three sub-makes in the same
     * tree: there is one rule that recurses, and these all wait for
     * it.
     *
     * The stamp is written after the sub-make finishes, so it is
     * newer than anything the sub-make produced -- which would leave
     * every one of these permanently out of date, and everything
     * downstream of them rebuilding on every make.  Touching settles
     * that in one step and says something true while it's at it: the
     * tree has just been rebuilt, so whatever depends on this output
     * should look again. */
    for (const auto& path: _subproject_targets) {
        auto target = build_dir() + "/" + path;

        auto commands = std::vector<std::string>{
            "test -e " + target + " || {"
            " echo \"" + name() + ": '" + path + "' is not in '"
            + build_dir() + "' after building '" + source_dir()
            + "'\";"
            " echo \"  a SUBPROJECT_TARGETS names a file the tree builds,"
            " relative to where it builds it\";"
            " exit 1; }",
            "touch " + target,
        };

        out.push_back(std::make_shared<makefile::target>(
            target,
            std::string(),
            std::vector<makefile::target::ptr>{
                std::make_shared<makefile::target>(build_stamp())
            },
            /* A plain "make" asks for these, which costs nothing --
             * the tree has already built them by then -- and buys the
             * check above.  Without it a SUBPROJECT_TARGETS that names
             * a file the tree doesn't build stays quiet until
             * something happens to want that file, which is a long
             * way from the line that got it wrong. */
            std::vector<makefile::global_targets>{
                makefile::global_targets::ALL,
            },
            commands,
            std::vector<std::string>{
                "'" + path + "', which the vendored build system in "
                + source_dir() + " was said to produce"
            }));
    }

    return out;
}

std::string build_system::configure_signature(void) const
{
    /* One option per line, in the order they were given, character
     * for character.  The order is part of the answer -- a later
     * --configure is allowed to overwrite an earlier one -- so two
     * runs that gave the same options in a different order really are
     * two different runs.
     *
     * The raw lines are enough even though a build system turns them
     * into settings with defaults behind them, since a default can
     * only be moved off by an option and every option is here. */
    auto out = std::string();
    for (const auto& opt: _configureopts)
        out += opt + "\n";

    /* A MAKEOPS isn't a CONFIGUREOPTS, but it goes on the command
     * line of every sub-make written out of here -- including the one
     * that writes the configuration -- so changing one has changed
     * how the tree gets configured just as surely as an option
     * would.  The ones that arrived as an option are already up
     * there, written the way they were written. */
    for (size_t i = 0; i < _makeopts.size(); ++i)
        if (_makeopt_from_option[i] == false)
            out += "MAKEOPS " + _makeopts[i] + "\n";

    return out;
}

/* Drops the trailing '/' off a directory, which is the spelling that
 * every tool other than pconfigure's own bookkeeping wants. */
static std::string trim(const std::string& path)
{
    if (path.size() == 0)
        return ".";
    if (path[path.size() - 1] != '/')
        return path;
    return path.substr(0, path.size() - 1);
}

std::string build_system::source_dir(void) const
{
    return trim(_base);
}

std::string build_system::output_dir(void) const
{
    /* The build system comes first so that this can't land on top of
     * anything pconfigure puts in an object directory, and the
     * subproject second so that two trees built the same way can't
     * land on top of each other.
     *
     * That path is spelled the way it looks from inside the project
     * that owns the object directory: the object directory is already
     * based there, and basing the subproject again would produce
     * "sub/obj/kconfig/sub/linux". */
    return _context->obj_dir + "/" + _name
         + "/" + trim(_context->unbased(_base));
}

build_system::ptr build_system::bind(const std::string& base,
                                     const context::ptr& context) const
{
    auto out = dup();
    out->_base = base;

    /* A copy of the context rather than the context itself.  What
     * gets bound here is the live top of the Configfile's stack, and
     * the rest of the file keeps writing to it: a CROSS_COMPILE five
     * lines further down would otherwise reach back and change what
     * this subproject was built with, which is not what a line
     * written after a SUBPROJECTS means anywhere else. */
    out->_context = context->dup();
    return out;
}

build_system::ptr build_system::create(const std::string& name)
{
    if (name == "pconfigure")
        return std::make_shared<build_system_pconfigure>(name);
    if (name == "kconfig")
        return std::make_shared<build_system_kconfig>(name);
    if (name == "buildroot")
        return std::make_shared<build_system_buildroot>(name);

    return NULL;
}

std::vector<std::string> build_system::names(void)
{
    return std::vector<std::string>{"pconfigure", "kconfig", "buildroot"};
}
