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

#include "target.h++"

makefile::target::target(const std::string& name,
                         const std::string& short_cmd,
                         const std::vector<target::ptr>& deps,
                         const std::vector<global_targets>& global,
                         const std::vector<std::string>& cmds,
                         const std::vector<std::string>& comment)
    : _name(name),
      _short_cmd(short_cmd),
      _deps(deps),
      _global(global),
      _cmds(cmds),
      _comment(comment),
      _phony(false),
      _included(false),
      _clean_extra()
{
}

makefile::target::target(const std::string& name)
    : _name(name),
      _short_cmd(),
      _deps(),
      _global(),
      _cmds(),
      _comment(),
      _phony(false),
      _included(false),
      _clean_extra()
{
}

makefile::target::ptr makefile::target::without(makefile::global_targets mask) const
{
    auto global = std::vector<global_targets>();
    for (const auto g: _global)
        if (g != mask)
            global.push_back(g);

    auto out = std::make_shared<target>(_name,
                                        _short_cmd,
                                        _deps,
                                        global,
                                        _cmds,
                                        _comment);

    /* Taking a target out of "all" says nothing about whether it is a
     * name rather than a file, or whether it is a piece of Makefile
     * somebody includes.  Dropping either of those here would be this
     * function quietly changing something it was not asked about --
     * and the way that shows up is a rule that stops firing, or a
     * fragment that nothing reads. */
    out->_phony = _phony;
    out->_included = _included;
    out->_clean_extra = _clean_extra;
    return out;
}

makefile::target::ptr makefile::target::as_phony(void) const
{
    auto out = std::make_shared<target>(_name,
                                        _short_cmd,
                                        _deps,
                                        _global,
                                        _cmds,
                                        _comment);
    out->_phony = true;
    out->_included = _included;
    out->_clean_extra = _clean_extra;
    return out;
}

makefile::target::ptr makefile::target::as_included(void) const
{
    auto out = std::make_shared<target>(_name,
                                        _short_cmd,
                                        _deps,
                                        _global,
                                        _cmds,
                                        _comment);
    out->_phony = _phony;
    out->_included = true;
    out->_clean_extra = _clean_extra;
    return out;
}

makefile::target::ptr makefile::target::with_clean_extra(const std::string& path) const
{
    auto out = std::make_shared<target>(_name,
                                        _short_cmd,
                                        _deps,
                                        _global,
                                        _cmds,
                                        _comment);
    out->_phony = _phony;
    out->_included = _included;
    out->_clean_extra = _clean_extra;
    out->_clean_extra.push_back(path);
    return out;
}

bool makefile::target::has_global_target(const global_targets& g) const
{
    for (const auto& myg: _global)
        if (myg == g)
            return true;

    return false;
}

void makefile::target::write_to_file(FILE *file,
                                     bool verbose,
                                     const std::string& check_stamp,
                                     const path_prefix& prefix) const
{
    /* Every path this target knows about is relative to where
     * pconfigure ran, and has to come out relative to where make will
     * run instead.  The name gets rewritten before anything is built
     * out of it so that the rule, the .PHONY line and the
     * clean/uninstall helpers all end up spelling it the same way. */
    auto name = prefix.rewrite(_name);

    /* First write a little header that adds the upcoming target to
     * any of the global targets that it may have ended up setting. */
    for (const auto& global_target: _global) {
        switch (global_target) {
        case global_targets::ALL:
            fprintf(file, "all: %s\n", name.c_str());
            break;
        case global_targets::CHECK:
            fprintf(file, "%s: %s\n", check_stamp.c_str(), name.c_str());
            break;
        case global_targets::CLEAN:
            fprintf(file, ".PHONY: __pconfigure__clean-%s\n", name.c_str());
            fprintf(file, "__pconfigure__clean-%s:; @rm -fr %s",
                    name.c_str(), name.c_str());
            /* Whatever else this target owns goes on the same rm, so
             * that a clean of it is one command that either happened
             * or didn't -- rather than a second rule that can be
             * dropped, reordered, or made to fail on its own. */
            for (const auto& extra: _clean_extra)
                fprintf(file, " %s", prefix.rewrite(extra).c_str());
            fprintf(file, "\n");
            fprintf(file, "clean: __pconfigure__clean-%s\n", name.c_str());
            break;
        case global_targets::INSTALL:
            fprintf(file, "install: %s\n", name.c_str());
            break;
        case global_targets::UNINSTALL:
            fprintf(file, ".PHONY: __pconfigure__uninstall-%s\n", name.c_str());
            fprintf(file, "__pconfigure__uninstall-%s:; @rm -f %s\n",
                    name.c_str(), name.c_str());
            fprintf(file, "uninstall: __pconfigure__uninstall-%s\n", name.c_str());
            break;
         }
    }

    /* This actually writes out the make rule that's necessary  */
    for (const auto& comment: _comment)
        fprintf(file, "# %s\n", comment.c_str());
    if (_phony == true)
        fprintf(file, ".PHONY: %s\n", name.c_str());
    fprintf(file, "%s:", name.c_str());
    for (const auto& dep: _deps)
        fprintf(file, " %s", prefix.rewrite(dep->_name).c_str());
    fprintf(file, "\n");
    /* A target with nothing to say says nothing.  The echo is what
     * a build prints while it works, and a rule that does no work
     * printing an empty line is just a blank line in the log. */
    if (_short_cmd.size() > 0)
        fprintf(file, verbose == false ? "\t@echo \"%s\"\n" : "\techo \"%s\"\n",
                _short_cmd.c_str());

    for (const auto& cmd: _cmds)
        fprintf(file, verbose == false ? "\t@%s\n" : "\t%s\n",
                prefix.rewrite(cmd).c_str());
    fprintf(file, "\n");
}

bool makefile::same_recipe(const target::ptr& a, const target::ptr& b)
{
    if (a->_cmds.size() != b->_cmds.size())
        return false;

    for (size_t i = 0; i < a->_cmds.size() && i < b->_cmds.size(); ++i)
        if (a->_cmds[i] != b->_cmds[i])
            return false;

    return true;
}

/* The loop prerequisite() and present_prerequisite() share: each of
 * the characters in "special" gets a backslash in front, which is how
 * make is told a character on a rule line is part of a name, and a '$'
 * is written "$$".  A backslash is only special to make in front of
 * one of those characters, where a run of them is read as escapes of
 * each other, so the backslashes in front of one are doubled first --
 * the same thing the rerun arguments do, for the same reason -- and the
 * path comes out the other side as it went in.  Anywhere else a
 * backslash is an ordinary character and is left alone. */
static std::string quote_for_make(const std::string& path,
                                  const std::string& special)
{
    auto out = std::string();
    auto backslashes = std::string();
    for (const auto& c: path) {
        if (c == '\\') {
            backslashes += c;
            continue;
        }
        if (special.find(c) != std::string::npos)
            out += backslashes + backslashes + "\\" + c;
        else if (c == '$')
            out += backslashes + "$$";
        else
            out += backslashes + c;
        backslashes.clear();
    }
    out += backslashes;
    return out;
}

/* The characters that make a word a glob.  make globs a prerequisite
 * with one of them in it and takes any other as the name it says,
 * while $(wildcard) globs everything it is handed; either way, once
 * it is a glob a backslash quotes the character after it, and a ']'
 * closes a class. */
static const std::string glob_characters = "*?[";

static std::string quote_for_glob(const std::string& path)
{
    auto out = std::string();
    for (const auto& c: path) {
        if (c == '\\' || c == ']' || glob_characters.find(c) != std::string::npos)
            out += '\\';
        out += c;
    }
    return out;
}

/* make reads three characters on a rule line as its own wherever they
 * sit in a word: a '#' starts a comment that runs to the end of the
 * line, taking the rest of this path and every prerequisite after it;
 * a '$' starts an expansion, so "cost$1.txt" is "cost" followed by
 * whatever the variable "1" holds; and a ':' is the separator of a
 * static pattern rule, so "src/a:b.txt" makes the line one with two
 * colons in it, which make stops on as "multiple target patterns".
 * The first two send make looking for a file nobody named; the third
 * leaves a Makefile that does not parse at all.
 *
 * A '$' is written "$$", a '#' "\#" and a ':' "\:", which are the
 * spellings make has for each, with the backslashes in front of either
 * doubled as quote_for_make() says.  Measured with GNU make 4.4.1: a
 * prerequisite spelled "x\\\:y" is the file "x\:y".
 *
 * A ';' would belong in that list too -- on a rule line it ends the
 * prerequisites and starts a recipe -- but make has no spelling for
 * one that is part of a file name: "\;" still ends the list, inside a
 * "$(wildcard ...)" as well as bare.  So a caller that can meet one
 * has to refuse it, naming the Configfile line the path came from, and
 * the same goes for every character unspellable() names.
 *
 * A space is the fourth, and it got here once the headers the scan
 * finds were spelled through this -- "my extra.h", or a header under
 * "-I/opt/my\ dir/include" -- since make splits a rule line into
 * names at a space and the object then waited on two files, the first
 * of which no rule made.  "\ " is make's spelling for a space that is
 * part of a name, with the backslashes in front doubled like the
 * others and measured the same way: "x\\\ y" is the file "x\ y".  A
 * '%' needs nothing as a prerequisite of an ordinary rule, where make
 * takes it as the character it is; on the left of a rule it is
 * rule_target()'s business. */
std::string makefile::prerequisite(const std::string& path)
{
    return quote_for_make(path, "#: ");
}

/* The same path on the left of a rule, which is where pdeps puts each
 * header it names so that one which has since been deleted is a file
 * make can remake rather than the end of the build.  Everything that
 * goes for a prerequisite goes here too, plus a '%': on the left of a
 * rule one makes the rule a pattern, and a pattern rule with no recipe
 * is not a rule for the file at all but the cancelling of an implicit
 * one.  "\%" is the literal there, and only there -- a prerequisite
 * spelled that way names a file with a backslash in it, which is why
 * this is a second function rather than one more character in the
 * first. */
std::string makefile::rule_target(const std::string& path)
{
    return quote_for_make(path, "#: %");
}

/* The characters make cannot be told are part of a name on a rule
 * line, whatever is put in front of them, each measured with GNU make
 * 4.4.1.  A ';' ends the prerequisites and starts a recipe, "\;"
 * included.  An '=' turns the line into a target-specific variable
 * assignment, escaped or not.  A '|' is the start of the order-only
 * prerequisites, and while "\|" does name the file as a prerequisite
 * it does not as a target, so the two sides of a rule cannot agree on
 * it; a tab is the same story.  A newline ends the rule.
 *
 * A caller that meets one has a name it cannot write and no spelling
 * to fall back on, so it says so, naming whatever led it to the path,
 * rather than write a rule about some other file. */
std::string makefile::unspellable(const std::string& path)
{
    for (const auto& c: path) {
        switch (c) {
        case ';':
            return "make reads a ';' on a rule line as the end of the"
                   " prerequisites and the start of a recipe, and has no"
                   " escape that makes one part of a name";
        case '=':
            return "make reads a rule line with an '=' in it as a"
                   " variable assignment, and has no escape that makes"
                   " one part of a name";
        case '|':
            return "make reads a '|' on a rule line as the start of the"
                   " order-only prerequisites, and its escape for one is"
                   " not read the same way on both sides of a rule";
        case '\t':
            return "make reads a tab on a rule line as the gap between"
                   " two names, and its escape for one is not read the"
                   " same way on both sides of a rule";
        case '\n':
            return "make reads a newline as the end of the rule, and has"
                   " no escape that makes one part of a name";
        }
    }
    return "";
}

/* Inside a function call make does not end the line at a '#', so one
 * there is an ordinary character and is left alone: "\#" would
 * reach $(wildcard) as a glob with a backslash in it, which matches
 * the file only by the grace of the glob's own escaping.  A '$' is
 * still an expansion there, so it is still doubled. */
std::string makefile::function_argument(const std::string& path)
{
    auto out = std::string();
    for (const auto& c: path) {
        if (c == '$')
            out += "$$";
        else
            out += c;
    }
    return out;
}

/* $(wildcard) is a glob, so a name with a '[' in it is a character
 * class and a backslash quotes whatever follows it: "notes[1].txt" is
 * looked for as "notes1.txt" and "notes\1.txt" as "notes1.txt" too,
 * the wildcard comes to nothing, and the file is silently not watched.
 * Each of the glob's own characters gets the backslash the glob reads
 * as "this one is just a character", and the '$' is doubled as it is
 * for any function argument.  A '#' needs nothing inside the call. */
std::string makefile::wildcard_argument(const std::string& path)
{
    return function_argument(quote_for_glob(path));
}

/* What $(wildcard) hands back is the bare name, and make reads that
 * as part of the rule line it was expanded on, after the expansion.
 * For most names that is the name.  A ':' is a second target
 * separator and stops every make on "multiple target patterns", a
 * ';' starts a recipe and a '|' the order-only prerequisites, so
 * either leaves the rule naming a file nobody made; and a name with a
 * glob character in it is globbed again, which finds "notes1.txt" for
 * "notes[1].txt" if there is one.  Nothing can spell the expansion
 * once it has happened, so for those names the expansion is not what
 * goes on the rule: the name does, spelled for the rule line by this
 * end, and the $(wildcard) only decides whether it is there at all.
 *
 * That is the third argument to a $(foreach) over what the
 * $(wildcard) found, rather than the second to an $(if), because the
 * last argument is the only one a ',' in the name cannot split.  The
 * $(wildcard) is of one name with the glob quoted out of it, so it
 * finds that file or nothing, and the $(foreach) says the name once or
 * not at all.  Inside a call a '#' is an ordinary character, both
 * before the expansion and after it, so it is the one character the
 * rule line would otherwise need that this leaves alone.
 *
 * A name that needs none of it keeps the plain $(wildcard), which is
 * what every Configfile on the rule is, and what anybody reading the
 * Makefile expects to find there.  Whitespace and an unmatched
 * parenthesis are still out of reach: there is no spelling of either
 * that a $(wildcard) and a rule line both read back as written. */
std::string makefile::present_prerequisite(const std::string& path)
{
    auto found = "$(wildcard " + wildcard_argument(path) + ")";
    if (path.find_first_of(":;|" + glob_characters) == std::string::npos)
        return found;

    auto globbed = path.find_first_of(glob_characters) != std::string::npos;
    auto name = quote_for_make(globbed ? quote_for_glob(path) : path, ":;|");
    return "$(foreach f," + found + "," + name + ")";
}
