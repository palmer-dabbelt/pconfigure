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
#include "build_systems/autotools.h++"
#include "build_systems/buildroot.h++"
#include "build_systems/cargo.h++"
#include "build_systems/cmake.h++"
#include "build_systems/kconfig.h++"
#include "build_systems/pconfigure.h++"
#include "file_utils.h++"
#include "string_utils.h++"
#include <sys/stat.h>
#include <cctype>
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

    take_makeopt(opt);

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
     * gets built by a sub-make that never touches it.
     *
     * Asked through the one function that decides what a Configfile
     * is allowed to name, rather than through a check of its own.
     * The check that stood here was written as
     * 'compare(0, 3, "../")', which is the spelling
     * checked_project_path()'s own comment says misses a bare ".." --
     * there is no trailing slash on that for this to match -- and a
     * bare ".." is the worst of them: it names the directory the
     * whole checkout is in, and it is what an earlier round of this
     * shipped as an "rm -rf ..".  It missed an absolute path with a
     * make expansion in it too, and a path with a space in it, each
     * of which goes wrong further down in a way that has nothing left
     * to say which line caused it.
     *
     * The rule is the same rule whichever directory the path is read
     * from, because all of it is lexical: a path that climbs out of
     * the project climbs out of the directory the tree builds into as
     * well, since that directory is inside the project.  What comes
     * back is resolved against the project and this wants it relative
     * to the build directory, so the answer is thrown away and the
     * question is what this was for. */
    checked_project_path("SUBPROJECT_TARGETS", path, "bin/tool");

    auto normalized = file_utils::normalize_path(path);

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
     * flag of its own.  string_utils::quoted() is where that is
     * spelled, and where the reasons for spelling it that way are
     * written down. */
    auto out = std::string();
    for (const auto& opt: _makeopts)
        out += " " + string_utils::quoted(opt);
    return out;
}

std::vector<makefile::target::ptr>
build_system::targets(const std::vector<ptr>& peers,
                      const std::string& project_base) const
{
    auto out = vendored_targets(peers, project_base);

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

        /* Two trees installing into one prefix is the reason the
         * option to name a prefix exists at all, and two trees that
         * both say they produce the same file inside it is that
         * reason gone wrong.  Both would get a rule here, so the
         * Makefile would carry two recipes for one target: make keeps
         * the last one it read, warns about it in the middle of a
         * build nobody is reading the output of, and builds the file
         * with whichever tree happened to be written second.
         *
         * Which of the two really builds it is not something that can
         * be worked out from here -- both Configfile lines say it is
         * theirs -- so this says so and stops rather than picking.
         *
         * Peers include this build system itself, which is not a
         * collision: it is the same line seen once. */
        for (const auto& peer: peers) {
            if (peer.get() == this)
                continue;
            if (peer->produces(target) == false)
                continue;

            std::cerr << name() << ": '" << target << "' is named by a"
                      << " SUBPROJECT_TARGETS under '" << source_dir()
                      << "' and by one under '" << peer->source_dir()
                      << "'\n"
                      << "  the two trees install into one directory, so both"
                      << " lines name one file -- and two recipes for one"
                      << " target is a build that uses whichever make read"
                      << " last\n"
                      << "  name the file under the one tree that builds it,"
                      << " or give the trees prefixes of their own\n";
            abort();
        }

        /* Every word of this that came out of a Configfile is quoted,
         * and the quoting is single because a SUBPROJECT_TARGETS is
         * text: this recipe used to be written with double quotes
         * round the message, which holds right up until the path in
         * it has a quote of its own.  A 'SUBPROJECT_TARGETS += a"b'
         * then ends the message's own quoting and hands the rest of
         * the recipe to the shell as whatever it makes of it, so what
         * a build prints is "unexpected EOF while looking for
         * matching" from a line whose entire job was to say which
         * file the tree didn't build.  A '$' does it the other way
         * round: make expands a recipe before the shell sees it, so a
         * path with one in it becomes whatever the variable held.
         *
         * Which is string_utils::echoed(), and the path itself gets
         * string_utils::quoted() for the same reason one step
         * earlier: the "test -e" that decides whether to say any of
         * this is the first thing the shell reads, so a quote in the
         * path breaks the line before the message is reached.
         *
         * None of that gets in the way of the path rewriting that
         * lets this Makefile be included by a parent's.  A quote is
         * one of the characters a path is allowed to start after, so
         * a path just inside these quotes is still found and still
         * gets its project's variable put in front of it -- which is
         * what keeps the message naming the file from wherever make
         * was run.  The variable that goes in is put there after the
         * doubling, so it is a '$' make still expands. */
        auto commands = std::vector<std::string>{
            "test -e " + string_utils::quoted(target) + " || {"
            " echo " + string_utils::echoed(
                    name() + ": '" + path + "' is not in '" + build_dir()
                    + "' after building '" + source_dir() + "'")
            + ";"
            " echo " + string_utils::echoed(
                    "  a SUBPROJECT_TARGETS names a file the tree builds,"
                    " relative to where it builds it")
            + ";"
            " exit 1; }",
            "touch " + string_utils::quoted(target),
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

/* Takes the source directory off the front of a path, when it's on
 * there.  A subproject is usually vendored into the same directory
 * everything else this project builds from lives in, and "src" said
 * again on the output side is a word that distinguishes nothing. */
static std::string unsourced(const context::ptr& ctx,
                             const std::string& dir)
{
    auto src = ctx->unbased(ctx->src_dir) + "/";
    if (dir.compare(0, src.size(), src) != 0)
        return dir;

    /* Unless taking it off leaves nothing, which is what a project
     * whose whole source directory is one vendored tree would get.
     * A directory has to have a name. */
    auto out = dir.substr(src.size());
    if (trim(out) == ".")
        return dir;
    return out;
}

std::string build_system::output_dir(void) const
{
    /* Named after the tree and after nothing else.  This is a path
     * people have to write down -- a TESTDEPS waits on what lands in
     * here, and a link line reaches into it -- so what it says should
     * be the part they had a choice about.  Which build system builds
     * the tree isn't that: it was decided by looking at what's in the
     * directory, and nobody who reads the Configfile picked it.
     * Neither is the source directory, which every subproject is
     * under and so tells no two of them apart.
     *
     * That leaves a tree at "src/linux" building into "obj/linux",
     * which can't land on top of pconfigure's own object files: those
     * keep the path they were compiled from, so they're all under
     * "obj/src".
     *
     * The subproject is spelled the way it looks from inside the
     * project that owns the object directory, since the object
     * directory is already based there and basing the subproject
     * again would produce "sub/obj/sub/linux". */
    return _context->obj_dir + "/"
         + trim(unsourced(_context, _context->unbased(_base)));
}

std::string build_system::unsafe_metacharacter(const std::string& written)
{
    /* Written out once, character for character, rather than built up
     * out of pieces: a list somebody has to be able to read straight
     * through and believe is the whole list. */
    static const std::string dangerous = ";&|`()<>\n";

    auto pos = written.find_first_of(dangerous);
    if (pos == std::string::npos)
        return "";

    return written.substr(pos, 1);
}

std::string
build_system::checked_project_path(const std::string& flag,
                                   const std::string& written,
                                   const std::string& example) const
{
    /* Asked of the path as the Configfile wrote it rather than of the
     * resolved one, and that is the whole difference between a rule
     * and a coincidence.  Resolving first turns a child's
     * "../obj/toolchain" into the parent's "obj/toolchain", which
     * climbs out of nothing and sails through -- so the same line is
     * legal read from the top and refused read from inside the child,
     * and the reading that accepts it is the one where it names a
     * directory belonging to somebody else's project. */
    auto relative = file_utils::normalize_path(written);

    if (relative.size() > 0 && relative[0] == '/') {
        std::cerr << name() << ": '" << flag << " " << written << "' is an"
                  << " absolute path\n"
                  << "  a path in a Configfile is read relative to the"
                  << " project that wrote it, so that the line means the same"
                  << " directory whether pconfigure was run in that project"
                  << " or above it\n"
                  << "  write it relative to that project, like '" << flag
                  << " " << example << "'\n";
        abort();
    }

    /* And a path with a make expansion in it, which is a path that
     * isn't a path yet.  Everything this function decides is decided
     * lexically, of the text exactly as the Configfile wrote it --
     * which is the whole of what makes the answer the same read from
     * the top and read from inside a subproject -- and what make
     * expands is not text anything out here can read.  The value then
     * goes into an "$(abspath ...)" in a recipe, where make expands
     * it, so a reference with no slash in it passes every check above
     * as one harmless-looking component and comes out the other side
     * as whatever the variable held: a '--prefix
     * obj/$(CURDIR:%=..)/$(CURDIR:%=..)/elsewhere' is lexically
     * inside the object directory, and a plain "make" installs it
     * beside the project.
     *
     * Refused rather than expanded here, because expanding it is the
     * bug this function exists to repudiate: pconfigure would have to
     * guess what make's variables hold at a point where make hasn't
     * read the Makefile yet, and a guess that was right on the
     * machine it was written on is a silent escape everywhere else.
     * Refused rather than passed through unexamined, because then the
     * check above is a check of something that isn't what the build
     * uses.
     *
     * It costs a spelling that nothing in this tree uses: the paths a
     * Configfile writes here are the project's own -- a prefix, a
     * --depend, a file a vendored tree builds -- and a project spells
     * those the way it spells a SOURCES.  A value that really does
     * have to be computed by make is one of the values that reach the
     * tree unread, which is what an --env and a --configure-var are
     * for and where "$(abspath x)" goes on meaning what it says. */
    if (written.find('$') != std::string::npos) {
        std::cerr << name() << ": '" << flag << " " << written << "' is a"
                  << " make expansion rather than a path\n"
                  << "  what a path in a Configfile names has to be decided"
                  << " here, from the text as it was written: this one is"
                  << " read by make instead, at which point nothing is left"
                  << " that could say whether what it came to is inside the"
                  << " project or somewhere else entirely\n"
                  << "  write it the way the project spells it, like '"
                  << flag << " " << example << "'\n";
        abort();
    }

    /* And a character a shell treats specially wherever it appears,
     * without needing a space beside it to do it: "a;b" is two
     * commands and "a>b" is one command with its output redirected,
     * exactly as "a ; b" and "a > b" are, so where the character sits
     * relative to a '/' or a ".." has nothing to do with whether it
     * is dangerous.  Asked after the '$' above rather than before it,
     * so that a path with both -- "$(CURDIR:%=..)" is a '$' and two
     * parentheses at once -- keeps the more specific answer: make
     * expands the whole of that before a shell ever reads any of it,
     * which is a hazard this function already has a name for.
     *
     * "lib;>/abs/PWNED;true" is a LIBDIR that was accepted, with
     * nothing said about it, right up until this existed: the value
     * becomes part of a linker command line pasted in unquoted (see
     * languages/cxx.c++'s _target_path), so the ';' ends that command
     * and the rest of the line is make's chosen shell running whatever
     * came after -- during a plain "make", with no install step in
     * sight. */
    auto metachar = unsafe_metacharacter(written);
    if (metachar.size() > 0) {
        std::cerr << name() << ": '" << flag << " " << written << "' has a"
                  << " '" << metachar << "' in it\n"
                  << "  this reaches a Makefile recipe as text, and a shell"
                  << " -- which is what runs that recipe -- reads a '"
                  << metachar << "' as an instruction of its own wherever it"
                  << " appears, with no space needed on either side: what"
                  << " this names is not the one path it looks like, it is"
                  << " that path followed by whatever the character tells a"
                  << " shell to do next\n"
                  << "  write it without one, like '" << flag << " "
                  << example << "'\n";
        abort();
    }

    /* Both spellings of climbing out, because the bare ".." is the one
     * a check written as "starts with '../'" lets through: there is no
     * trailing slash on it for that to match.  It is also the worst
     * one there is -- "../out" names a directory beside the project,
     * while ".." names the directory the project was checked out
     * into, which is everything. */
    if (relative == ".." || relative.compare(0, 3, "../") == 0) {
        std::cerr << name() << ": '" << flag << " " << written << "' reaches"
                  << " outside the project that wrote it\n"
                  << "  the Makefile names a path inside the project through"
                  << " that project's own prefix, which is what makes one"
                  << " line mean one directory from above and from inside;"
                  << " a path that climbs out has no such prefix and means"
                  << " two\n"
                  << "  write it inside the project, like '" << flag << " "
                  << example << "'\n";
        abort();
    }

    /* And a path with a space in it, which is a path make has no way
     * to spell.  Everything this becomes in the generated Makefile is
     * read as a list: a target line and a prerequisite list are split
     * on whitespace, and so is the argument of every make function
     * one of these ends up inside.  "$(abspath obj/my prefix)" is two
     * absolute paths rather than one -- so a tree is told to install
     * somewhere nobody named, and a rule written under the prefix
     * becomes two rules.  Nothing downstream can put that back
     * together, because by the time make has it there is no record
     * that the two words were ever one path.
     *
     * So this is refused rather than accommodated.  Accommodating it
     * would mean making every list in the generated output
     * whitespace-safe, and make has no quoting for the two places
     * that matter most: a target name and a prerequisite are bare
     * words, and the backslash escape that half works in one of them
     * does not work in the other.  What that would buy is a build
     * system that takes the line and then behaves differently
     * depending on which of its own outputs the path reached, which
     * is worse than a refusal and a great deal harder to explain.
     *
     * A space is the only whitespace that can get this far: a
     * Configfile line is run through string_utils::clean_white() as
     * it's read, so a tab and a run of spaces are both a single space
     * by now, and asking about the space asks about all of them.
     *
     * The same question about a whole Configfile line -- a
     * "SUBPROJECTS += my sub", a "LIBDIR = my dir" -- is asked and
     * answered elsewhere, in command_processor::process(), where it
     * is a strict::complain() rather than a refusal because those
     * commands are older than the rule and strict.h++ is where this
     * project writes down what it does about that.  It cannot be
     * asked up there for an option: the line an option arrives on is
     * a command line, where the spaces are what separate a flag from
     * its value, so a check at that level would have to complain
     * about every CONFIGUREOPTS anybody has ever written.  Which is
     * the whole reason this sits down here, where the one word that
     * is a path is known to be one. */
    if (written.find(' ') != std::string::npos) {
        /* The words it would arrive as, each in brackets, because
         * the whole of what is wrong here is how many paths this is
         * and a list printed bare reads as the one thing it was
         * meant to be. */
        auto split = std::string();
        for (const auto& word: string_utils::split_char(written, " "))
            split += "[" + word + "] ";

        std::cerr << name() << ": '" << flag << " " << written << "' has a"
                  << " space in it\n"
                  << "  make reads a path out of a Makefile as a word: a"
                  << " target line, a prerequisite list and the argument of"
                  << " a make function are each split on whitespace, so this"
                  << " reaches make as " << split << "rather than as one"
                  << " path -- and nothing further down can put it back\n"
                  << "  name it something with no space in it, like '"
                  << flag << " " << example << "'\n";
        abort();
    }

    return file_utils::normalize_path(_context->base + relative);
}

/* The directories inside a project's object directory that
 * pconfigure writes into itself.
 *
 * "pconfigure owns every byte under an object directory" is the
 * sentence the install-prefix rule rests on, and it cuts both ways:
 * owning the object directory is not the same as handing all of it
 * over.  The objects this project compiles land in one of these, the
 * programs it links in another, the files a GENERATE wrote in a
 * third -- and "make cache-clean" spares an install prefix whole,
 * since it cannot tell what an install left from what a
 * configuration abandoned.  So a prefix that landed on one of these
 * would be a cache-clean that reclaims nothing of the part of the
 * build it exists to reclaim, and would say nothing about it: the
 * target still runs and still finishes.
 *
 * Read off the context rather than written out as names, because
 * that is where they come from: a project that moved its SRCDIR or
 * its CHECKDIR moved these with it, and a list of literals here
 * would be a list that is right for the default project and quietly
 * wrong for the one that said otherwise. */
static std::vector<std::string> own_object_dirs(const context::ptr& ctx)
{
    auto out = std::vector<std::string>();

    /* Where a GENERATE writes, which is the one of these that is a
     * directory in its own right rather than the object directory
     * with an output directory's name stuck on the end. */
    out.push_back(file_utils::normalize_path(ctx->gen_dir));

    /* And where ppkg-config leaves what it wrote, which is named
     * here and nowhere a context can be asked about. */
    out.push_back(file_utils::normalize_path(ctx->obj_dir + "/pkgconfig"));

    /* The rest are the object directory with one of the output
     * directories' names on the end, which is how everything built
     * out of a source file gets a place to be built in: an object
     * keeps the path it was compiled from, and a link keeps the path
     * it will end up at. */
    for (const auto& dir: {ctx->src_dir, ctx->bin_dir, ctx->lib_dir,
                           ctx->libexec_dir, ctx->testexec_dir,
                           ctx->check_dir}) {
        auto name = file_utils::normalize_path(ctx->unbased(dir));

        /* A project whose source directory is the project itself has
         * nothing to stick on the end, and what it would name is the
         * object directory -- which is refused a line earlier, for
         * its own reasons. */
        if (name.size() == 0 || name == ".")
            continue;

        out.push_back(file_utils::normalize_path(ctx->obj_dir + "/" + name));
    }

    return out;
}

std::string build_system::checked_install_dir(const std::string& flag,
                                              const std::string& written) const
{
    const auto& obj = _context->obj_dir;

    /* Spelled the way the Configfile would have to spell it, which is
     * from inside the project rather than from where pconfigure ran,
     * and read off the object directory rather than written out here:
     * advice that named a directory the project hasn't got would send
     * somebody round the same refusal twice. */
    auto example = _context->unbased(obj) + "/toolchain";

    auto out = checked_project_path(flag, written, example);

    if (out == obj) {
        std::cerr << name() << ": '" << flag << " " << written << "' is the"
                  << " object directory itself rather than a directory"
                  << " inside it\n"
                  << "  'make cache-clean' spares an install prefix, since it"
                  << " cannot tell what an install left from what a"
                  << " configuration abandoned, so a prefix that is the whole"
                  << " of '" << obj << "' is a cache-clean that reclaims"
                  << " nothing\n"
                  << "  write a directory inside it, like '" << flag << " "
                  << example << "'\n";
        abort();
    }

    if (file_utils::inside(out, obj) == false) {
        std::cerr << name() << ": '" << flag << " " << written << "' names '"
                  << out << "', which is outside '" << obj << "'\n"
                  << "  a vendored tree installs into the object directory of"
                  << " the project that vendored it, because that is the one"
                  << " directory a build owns outright: what is under there"
                  << " is build output and nothing else, so 'make distclean'"
                  << " can remove it whole and 'make cache-clean' can be told"
                  << " to leave this part of it alone\n"
                  << "  anywhere else is a directory somebody's checkout may"
                  << " be in, and a prefix does not get to decide that\n"
                  << "  write a directory inside '" << obj << "', like '"
                  << flag << " " << example << "'\n";
        abort();
    }

    /* And not on top of the part of the object directory this project
     * builds into itself.  Overlapping either way round: a prefix
     * inside one of these is a prefix in the middle of somewhere the
     * build is already writing, and a prefix with one of them inside
     * it spares that one along with everything else it holds. */
    for (const auto& ours: own_object_dirs(_context)) {
        if (file_utils::inside(out, ours) == false
            && file_utils::inside(ours, out) == false)
            continue;

        std::cerr << name() << ": '" << flag << " " << written << "' names '"
                  << out << "', which is where this project builds\n"
                  << "  '" << ours << "' is pconfigure's own: it holds what"
                  << " this project compiled, linked or generated, and every"
                  << " byte of it has a rule behind it\n"
                  << "  'make cache-clean' spares an install prefix whole,"
                  << " since it cannot tell what an install left from what a"
                  << " configuration abandoned -- so a prefix here is a"
                  << " cache-clean that reclaims none of the cache it exists"
                  << " to reclaim, and says nothing about it\n"
                  << "  give the tree a directory of its own inside '" << obj
                  << "', like '" << flag << " " << example << "'\n";
        abort();
    }

    return out;
}

namespace {
    /* The decoration one word arrived wearing: the longest of the
     * ones this tree's command line uses that the word starts with.
     *
     * Longest rather than first, because they overlap and a short one
     * would win a race nobody meant to run: "-D" and "-" both match a
     * "-DCMAKE_INSTALL_PREFIX=/opt", and taking only the "-" off
     * leaves a name of "DCMAKE_INSTALL_PREFIX" that matches nothing
     * at all.  The empty decoration always matches, which is what
     * makes a bare "NAME=VALUE" a spelling like any other. */
    std::string decoration_of(const std::string& word,
                              const std::vector<std::string>& decorations)
    {
        auto out = std::string();

        for (const auto& decoration: decorations) {
            if (decoration.size() < out.size())
                continue;
            if (decoration.size() > word.size())
                continue;
            if (word.compare(0, decoration.size(), decoration) != 0)
                continue;

            out = decoration;
        }

        return out;
    }

    /* TRUE when the name a word carries is the given one.
     *
     * "abbreviated" is what a generated configure does: autoconf
     * writes out every truncation of every option name it takes, so a
     * name that is a prefix of one of these is that one.  It is asked
     * only of the spelling autoconf abbreviates, which the caller
     * decides, and never of a name that is empty -- a bare "--" would
     * otherwise be a prefix of everything. */
    bool same_name(const std::string& written,
                   const std::string& name,
                   bool abbreviated)
    {
        if (written.size() == 0)
            return false;
        if (written == name)
            return true;
        if (abbreviated == false)
            return false;
        if (written.size() > name.size())
            return false;

        return name.compare(0, written.size(), written) == 0;
    }

    /* TRUE when a word is one of the whole-word spellings: the word
     * itself, the word with a value stuck to it when the spelling is
     * short enough to be one of those ("-B/tmp/x"), or the word with
     * a value after an '=' when it isn't. */
    bool same_word(const std::string& word, const std::string& name)
    {
        if (name.size() == 0 || word.size() < name.size())
            return false;
        if (word.compare(0, name.size(), name) != 0)
            return false;

        auto rest = word.substr(name.size());
        if (rest.size() == 0)
            return true;
        if (name.size() <= 2 && name[0] == '-')
            return true;

        return rest[0] == '=';
    }

    /* One word as the tree will see it, as far as anything out here
     * can say: with the shell's quoting characters taken out of it.
     *
     * The raw options -- cmake's --configure-arg is the one -- reach a
     * recipe unquoted, which is what they are for, so the shell reads
     * them before the tree does and what it does first is take the
     * quoting off.  A '-D"CMAKE_INSTALL_PREFIX"=/opt' is the prefix
     * said again with two characters in it that never reach cmake,
     * and a check that matched the text as written saw a variable
     * called '"CMAKE_INSTALL_PREFIX"' and had no opinion about it.
     * The same goes for a value: a 'bindir=\\/usr\\/local\\/bin' is an
     * absolute path that does not start with a '/' until the shell
     * has had it.
     *
     * Taking them out is not a shell, and is not meant to be: it is
     * right for a word with no spaces in it, which is every word this
     * is asked about, and it errs the one safe way -- a name that was
     * hidden becomes visible and a value that was hiding an absolute
     * path starts looking like one, so what it can do is refuse more
     * rather than less. */
    std::string unquoted(const std::string& word)
    {
        auto out = std::string();

        for (const auto& c: word)
            if (c != '\'' && c != '"' && c != '\\')
                out += c;

        return out;
    }

    /* TRUE when a value handed to one of the subdirectories cannot
     * name anything outside the prefix it is read under.
     *
     * Written as what a value may be rather than as what it may not,
     * which is the way round that survives being wrong: the things
     * between this and the tree are make's expansion and the shell's
     * word rewriting, and a list of the characters they act on is a
     * list somebody has to keep in step with two other programs.  An
     * ordinary relative path -- letters, digits and the handful of
     * punctuation a directory name has in it -- goes through both of
     * them unchanged, and anything else is a value this cannot read
     * and so will not take.
     *
     * Above that sit the two ways an ordinary path still leaves the
     * prefix: an absolute one ignores it outright, and a ".." climbs
     * out of it.
     *
     * A value that isn't there at all is not one of these: the word
     * said a name and left the value for the next argument, which is
     * a value this cannot see and so cannot let through. */
    bool stays_under_prefix(const std::string& value)
    {
        if (value.size() == 0)
            return false;
        if (value[0] == '/')
            return false;

        for (const auto& c: value) {
            /* Through an unsigned char, which is the only thing the
             * ctype functions are defined for: a byte above 0x7f
             * arrives at a plain 'char' as a negative number and
             * indexes the table the implementation keeps in front of
             * it. */
            if (isalnum((unsigned char)c) != 0)
                continue;
            if (c == '/' || c == '.' || c == '-' || c == '_' || c == '+')
                continue;

            return false;
        }

        for (const auto& part: string_utils::split_char(value, "/"))
            if (part == "..")
                return false;

        return true;
    }

    /* The first line of every one of these, which quotes the
     * Configfile line back and says which of the tree's own names it
     * sets. */
    void refused(const std::string& system,
                 const std::string& flag,
                 const std::string& written,
                 const std::string& set,
                 const std::string& decides)
    {
        std::cerr << system << ": '" << flag << " " << written << "' sets '"
                  << set << "', which " << decides << "\n";
    }

    /* The two sentences the install refusals share, which are about
     * where a vendored tree is allowed to install rather than about
     * which spelling was used to say otherwise. */
    void why_it_matters(void)
    {
        std::cerr << "  the install here runs during 'make' rather than"
                  << " during 'make install', so a destination this build"
                  << " system didn't decide is a plain 'make' writing"
                  << " wherever that line pointed -- '/usr/local' is one"
                  << " character away\n"
                  << "  where a vendored tree installs is one question with"
                  << " one answer: a directory inside this project's object"
                  << " directory, which 'make distclean' removes whole and"
                  << " 'make cache-clean' is told to spare\n";
    }

    /* And the one the other kind shares, which is about the two
     * directories this build system has already named. */
    void already_named(void)
    {
        std::cerr << "  a SUBPROJECTS says which tree gets built and this"
                  << " build system says where it builds, and both of those"
                  << " are already on the command line this word would go"
                  << " on -- so which of the two the tree obeys is decided"
                  << " by the order this code composes that line in, which"
                  << " is not a thing the Configfile says\n"
                  << "  what comes of the tree obeying the other one is a"
                  << " build directory nothing in this project ever removes,"
                  << " or a tree built that no SUBPROJECTS ever named\n";
    }
}

void build_system::refuse_second_answer(const std::string& flag,
                                        const std::string& written) const
{
    auto tree = already_answered();

    /* Every whitespace-separated word of it rather than the first,
     * because an option that reaches the tree raw is written the way
     * it will appear on a command line: one of these is several
     * arguments, and the one that matters may be any of them. */
    for (const auto& raw: string_utils::split_char(written, " \t")) {
        auto word = unquoted(raw);
        if (word.size() == 0)
            continue;

        /* The whole-word spellings first, since they are the ones
         * with no name in them to look for. */
        for (const auto& directory: tree.directories) {
            if (same_word(word, directory.name) == false)
                continue;

            refused(name(), flag, written, directory.name, directory.decides);
            already_named();
            abort();
        }

        auto decoration = decoration_of(word, tree.decorations);
        auto rest = word.substr(decoration.size());

        /* The name is what comes before the value, and a value starts
         * at the first '=' -- or at the ':' of a cmake "-D" that
         * carries a type, which is part of neither. */
        auto named = rest.substr(0, rest.find_first_of("=: \t"));

        auto value = std::string();
        auto equals = rest.find('=');
        if (equals != std::string::npos)
            value = rest.substr(equals + 1);

        /* A name make computes is a name nothing here can read, and
         * it is asked about only where a word really does set
         * something -- there is an '=' in it, and what is in front of
         * the '=' is the name.  '-D$(WHATEVER)=1' is that, and so is
         * the '$(NOTHING)-DCMAKE_INSTALL_PREFIX=/usr/local' that
         * expands to a prefix with an empty variable stuck on the
         * front of it.
         *
         * Only there, because a word with no '=' in it is as likely
         * to be a value as a name -- a '--toolchain $(abspath
         * tc.cmake)' is two words and the second is a path somebody
         * meant -- and refusing those would be refusing the spelling
         * rather than the hazard.  What is left after that is a word
         * make assembles whole out of a variable nothing here set,
         * which is not a line that means something other than what it
         * says: it is a line written to get past this, by the person
         * who could have written the name outright.
         *
         * The '`' beside the '$' is belt and braces.  A Configfile's
         * own backticks are run by the reader that reads the line, so
         * one that reaches this far reached it some way this doesn't
         * know about -- and a name this can't read is a name this
         * can't read, however it came to be one. */
        if (equals != std::string::npos
            && (named.find('$') != std::string::npos
                || named.find('`') != std::string::npos)) {
            std::cerr << name() << ": '" << flag << " " << written << "' sets"
                      << " a variable whose name make works out: '" << named
                      << "'\n"
                      << "  what a word on the tree's command line sets has to"
                      << " be decided here, from the text as it was written,"
                      << " because the one thing it may not set is where the"
                      << " tree installs -- and a name that is only a name"
                      << " after make has expanded it is a name this has"
                      << " nothing to compare\n"
                      << "  write the variable out, and let the value be the"
                      << " part make works out\n";
            abort();
        }

        /* A name that is not the text written here by the time
         * anything else reads it -- unconditionally, unlike the '$'
         * above, because every one of these rewrites the word whether
         * or not it happens to carry an '=': a bare "-U" glob has
         * nothing else to it, and cmake reads the whole of what
         * follows the decoration as the name it deletes.
         *
         * '{' and '}' are bash's brace expansion, and a
         * '--configure-arg' is pasted into its recipe unquoted, by
         * design, so bash reads it before cmake ever does: a
         * '-DCMAKE_INSTALL_PRE{F,F}IX=/tmp/x' is, character for
         * character, "CMAKE_INSTALL_PRE{F,F}IX" here and
         * "CMAKE_INSTALL_PREFIX" twice by the time cmake sees it --
         * confirmed against the real cmake this was built with, doing
         * exactly that.  '*', '?' and '[' are a glob, which is what
         * makes '-U' different from every other decoration on this
         * list: cmake matches "-U"'s argument against every cache
         * variable's name itself, at a point this has no way to ask
         * about, so a literal comparison of the text written here was
         * never answering the right question for that one decoration
         * to begin with -- a '--configure-arg -UCMAKE_INSTALL_P*'
         * names no destination below character for character, and
         * unsets the one it was never asked whether it should.  A '`'
         * is the same hazard the '$' above already refuses, asked
         * again without waiting for an '=' to be sure it is a name: a
         * bare "-U `id`" has no value component for that word to be a
         * value of.
         *
         * Asked of every word this function sees rather than only of
         * the ones that turn out to match something on the lists
         * below: a name one of these is about to rewrite is a name
         * this cannot compare at all, so waiting to see whether it
         * matches first would still miss whatever list is written
         * next.  What this does not do is refuse '$' the same way,
         * unconditionally: a bare "--toolchain $(abspath tc.cmake)" is
         * two words, and make's own "$(abspath ...)" already means
         * what it says by the time this reads it -- that is the
         * escape hatch checked_project_path()'s own comment points to
         * for a value that really does have to be computed, and nothing
         * above takes it away. */
        if (named.find_first_of("{}*?[`") != std::string::npos) {
            std::cerr << name() << ": '" << flag << " " << written << "' sets"
                      << " a variable whose name is not the text written"
                      << " down: '" << named << "'\n"
                      << "  this is pasted into a recipe unquoted, and a"
                      << " shell reads it before the tree does: a '{' or a"
                      << " '}' is brace expansion, and a '*', a '?' or a"
                      << " '[' is a glob -- bash's own, or cmake's own on a"
                      << " '-U' -- so what this reads is not the name the"
                      << " tree receives, and a literal comparison of it"
                      << " answers nothing\n"
                      << "  name the one variable you mean, with none of"
                      << " those characters in it\n";
            abort();
        }

        /* autoconf spells its options with dashes and its variables
         * with underscores, and "--exec-prefix" and "exec_prefix" are
         * one thing. */
        if (tree.dashed == true)
            for (auto& c: named)
                if (c == '-')
                    c = '_';

        /* Only the "--" spelling is shortened, because that is the
         * only one autoconf shortens: its single-dash forms are the
         * whole name and nothing less. */
        auto abbreviated = tree.abbreviated == true && decoration == "--";

        for (const auto& directory: tree.directories) {
            if (same_name(named, directory.name, abbreviated) == false)
                continue;

            refused(name(), flag, written, directory.name, directory.decides);
            already_named();
            abort();
        }

        for (const auto& destination: tree.destinations) {
            if (same_name(named, destination.name, abbreviated) == false)
                continue;

            refused(name(), flag, written, destination.name,
                    destination.decides);
            why_it_matters();

            if (tree.prefix_option.size() > 0)
                std::cerr << "  write '" << tree.prefix_option << "' instead,"
                          << " which is the same thing said where the rest of"
                          << " the build can read it\n";
            else
                std::cerr << "  there is no option here that says it, because"
                          << " nothing here installs: what this tree builds"
                          << " stays in the directory it was built in\n";
            abort();
        }

        for (const auto& subdirectory: tree.subdirectories) {
            if (same_name(named, subdirectory.name, abbreviated) == false)
                continue;

            /* The one place in here that reads a value rather than a
             * name.  One of these is not a second answer to where the
             * tree installs -- it is one part of the layout
             * underneath it -- so what decides it is whether the
             * value can reach outside the prefix at all. */
            if (tree.relative_subdirectories == true
                && stays_under_prefix(value) == true)
                continue;

            refused(name(), flag, written, subdirectory.name,
                    subdirectory.decides);
            why_it_matters();

            if (tree.relative_subdirectories == true)
                std::cerr << "  a relative value is read under the prefix and"
                          << " can't leave it, so that is the one this takes:"
                          << " write '" << subdirectory.name << "=lib' rather"
                          << " than a path of its own.  What that means is an"
                          << " ordinary relative path and nothing else: one"
                          << " that starts at the root, one with a '..' in it"
                          << " and one carrying a character that make or the"
                          << " shell would act on before the tree read it are"
                          << " each a value this can't say stays inside\n";
            else
                std::cerr << "  and a relative value is no way round it here:"
                          << " the tree's own make reads one of these from the"
                          << " directory it builds in rather than from the"
                          << " prefix, so there is no spelling of 'under the"
                          << " prefix' for this to take\n";

            if (tree.relative_subdirectories == false
                && tree.prefix_option.size() > 0)
                std::cerr << "  write '" << tree.prefix_option << "', which"
                          << " moves the whole install; what the layout under"
                          << " it is is the tree's own business\n";
            abort();
        }
    }
}

void build_system::checked_env(const std::string& flag,
                               const std::string& written,
                               const std::string& example) const
{
    auto equals = written.find('=');
    if (equals == std::string::npos) {
        std::cerr << name() << ": '" << flag << " " << written << "' has no"
                  << " value: it should look like '" << flag << " " << example
                  << "'\n";
        abort();
    }

    auto variable = written.substr(0, equals);
    auto named = variable.size() > 0;
    for (size_t i = 0; i < variable.size(); ++i) {
        /* Through an unsigned char, which is the only thing the
         * ctype functions are defined for: they are specified over
         * the values of an unsigned char plus EOF, and a plain 'char'
         * is signed on every machine this builds on, so a byte above
         * 0x7f arrives as a negative number and indexes the table the
         * implementation keeps in front of it. */
        auto c = (unsigned char)variable[i];

        /* A digit is a name character everywhere but at the front,
         * where it is what turns the whole assignment back into a
         * command word. */
        if (c == '_' || isalpha(c) != 0)
            continue;
        if (i > 0 && isdigit(c) != 0)
            continue;

        named = false;
        break;
    }

    if (named == true)
        return;

    std::cerr << name() << ": '" << flag << " " << written << "' doesn't"
              << " start with a variable name: '" << variable << "' isn't"
              << " one\n"
              << "  the name goes in front of the command as a shell"
              << " assignment, which is the one part of this that can't be"
              << " quoted, so it has to be what a shell reads as a name: a"
              << " letter or a '_', then letters, digits and '_'\n"
              << "  write something like '" << flag << " " << example
              << "'\n";
    abort();
}

std::string build_system::option_value(const std::string& opt,
                                       const std::string& flag)
{
    if (opt.compare(0, flag.size(), flag) != 0)
        return "";

    auto rest = opt.substr(flag.size());
    if (rest.size() == 0)
        return "";
    if (rest[0] != ' ' && rest[0] != '=')
        return "";

    return string_utils::clean_white(rest.substr(1));
}

std::string build_system::resolve_depend(
    const std::string& flag,
    const std::string& path,
    const std::vector<build_system::ptr>& peers) const
{
    /* Through the one function that decides what a Configfile is
     * allowed to name, rather than through a check of its own.  The
     * check that used to stand here resolved the path first and
     * asked afterwards, which is the shape checked_project_path() was
     * written to repudiate: a child's '../shared.txt' resolves to the
     * parent's 'shared.txt', climbs out of nothing, and sails
     * through -- so the same line is legal read from the top and
     * refused read from inside the child, and the reading that
     * accepts it writes a bare 'shared.txt' into the child's
     * Makefile with no prefix variable in front of it.  A path
     * inside the project gets that variable and means one file from
     * either direction; this one means whichever file make happens
     * to be standing next to.
     *
     * A subproject is spelled here the same way it was spelled in the
     * SUBPROJECTS that pulled it in, so the same normalizing has to
     * tidy both: two spellings of one directory that don't come out
     * identical are two different directories as far as the search
     * below can tell.
     *
     * 'toolchain' is the shape rather than a directory anybody has:
     * what a --depend usually names is another SUBPROJECTS of the
     * same project, which is a directory beside this one. */
    auto file = checked_project_path(flag, path, "toolchain");
    auto dir = file_utils::normalize_directory(file);

    if (dir == base()) {
        std::cerr << name() << ": '" << flag << " " << path << "' names this"
                  << " subproject\n";
        abort();
    }

    /* Peers are the trees this same project vendored, and only those:
     * targets are generated at the end of every project, so a tree
     * some other project pulled in was never in this list and falls
     * through to the error at the bottom.  Within one project the
     * order doesn't matter, since every SUBPROJECTS has been read
     * before any of this runs. */
    for (const auto& peer: peers)
        if (peer->base() == dir && peer->build_stamp().size() > 0)
            return peer->build_stamp();

    /* A file another tree in this run says it builds is a target with
     * a rule behind it, so waiting for it is waiting for that rule.
     * It doesn't have to exist yet, which is the whole difference
     * between this and the check below: on a fresh checkout nothing
     * any of these trees produces exists. */
    for (const auto& peer: peers)
        if (peer.get() != this && peer->produces(file) == true)
            return file;

    struct stat buf;
    if (stat(file.c_str(), &buf) == 0 && S_ISREG(buf.st_mode) == true)
        return file;

    /* A pconfigure subproject is never a peer -- it's read into this
     * run rather than built by one -- so it always lands here, which
     * is where a typo lands too and both want the same advice. */
    if (stat(dir.c_str(), &buf) == 0 && S_ISDIR(buf.st_mode) == true) {
        std::cerr << name() << ": '" << flag << " " << path << "' names '"
                  << dir << "', which isn't a vendored subproject\n"
                  << "  a pconfigure subproject has no one file that says"
                  << " it's been built,\n"
                  << "  so name the file you actually need instead\n";
        abort();
    }

    std::cerr << name() << ": '" << flag << " " << path << "' names '"
              << file << "', which is neither a file nor a vendored"
              << " subproject\n";
    abort();
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
    if (name == "autotools")
        return std::make_shared<build_system_autotools>(name);
    if (name == "cmake")
        return std::make_shared<build_system_cmake>(name);
    if (name == "cargo")
        return std::make_shared<build_system_cargo>(name);

    return NULL;
}

std::vector<std::string> build_system::names(void)
{
    return std::vector<std::string>{"pconfigure", "kconfig", "buildroot",
                                   "autotools", "cmake", "cargo"};
}
