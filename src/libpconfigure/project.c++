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

#include "project.h++"
#include "commands.h++"
#include "file_utils.h++"
#include "pick_language.h++"
#include "string_utils.h++"
#include "languages/gen_proc.h++"
#include <libmakefile/self_path.h++>
#include <sys/stat.h>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <iostream>

project::project(const std::string& base,
                 const command_processor::ptr& processor,
                 const command::ptr& asked_by)
: _base(base),
  _processor(processor),
  _asked_by(asked_by)
{
}

std::string project::normalize_base(const std::string& path)
{
    return file_utils::normalize_directory(path);
}

std::string project::prefix_variable(const std::string& base)
{
    /* The variable has to name this project and nobody else, so it's
     * built from where the project is -- which is unique by
     * definition, once the path has been normalized.  Everything that
     * make would object to becomes an underscore. */
    auto suffix = std::string();

    auto was_word = false;
    for (const auto& c: base) {
        if (isalnum(c) != 0) {
            if (was_word == false && suffix.size() > 0)
                suffix += '_';
            suffix += c;
            was_word = true;
        } else {
            was_word = false;
        }
    }

    return "pconfigure_subdir_" + suffix;
}

void project::check_prefix_variables(const std::vector<ptr>& everyone)
{
    /* Two projects whose directories mangle to the same variable
     * would each think the variable was theirs, and one of them would
     * end up building into the other's directory.
     *
     * Refused rather than mangled apart.  A spelling that kept "lib-a"
     * and "lib_a" distinct would have to escape the underscore too,
     * which renames the variable of every project with one in its
     * path -- and that name is written into the dependency fragments
     * a build leaves behind, and read back out of them by the tools
     * that rewrite those for a parent.  Directories that differ only
     * in their punctuation are rare enough, and confusing enough to
     * a person as well, that asking for one of them to be renamed is
     * the cheaper answer.
     *
     * Asked once the whole run has been read rather than as each
     * subproject is, because the two lines can be in different
     * Configfiles and either one can come first. */
    auto where = [](const ptr& p) -> std::string
        {
            if (p->asked_by() == NULL)
                return "is the project pconfigure was run in";
            return "was asked for by " + std::to_string(p->asked_by()->debug());
        };

    auto variables = std::map<std::string, ptr>();
    for (const auto& project: everyone) {
        auto variable = prefix_variable(project->base());
        auto found = variables.find(variable);
        if (found == variables.end()) {
            variables[variable] = project;
            continue;
        }

        /* Pointed at the line of the later one, since that's the line
         * that made the pair; the earlier one gets named too, because
         * it is just as much the one somebody might want to rename. */
        const auto& first = found->second;
        if (project->asked_by() != NULL)
            std::cerr << std::to_string(project->asked_by()->debug()) << "\n";
        std::cerr << "  error: '" << project->base() << "' and '"
                  << first->base() << "' both come out as the make variable '"
                  << variable << "'\n"
                  << "  '" << first->base() << "' " << where(first) << "\n"
                  << "  every project's Makefile finds its directory through"
                  << " that variable, which is the directory's name with its"
                  << " punctuation squeezed down to underscores, so the two"
                  << " would each be building in the other's directory\n"
                  << "  rename one of the two directories so that their"
                  << " names differ in more than punctuation\n";
        abort();
    }
}

/* What makes two project directories the same project: where the
 * directory is once symlinks are resolved, so that two spellings of
 * one tree agree.  The top's base is empty, which realpath() won't
 * take, so it is asked as ".".  A directory that doesn't resolve has
 * no identity but its name, which can't collide with a resolved one
 * since resolved paths are absolute and no project base is. */
static std::string identity(const std::string& base)
{
    auto real = file_utils::real_directory(base.size() == 0 ? "." : base);
    return real.size() > 0 ? real : base;
}

/* Registers one CONFIG_DEPS that a Configfile in the project at
 * "srcpath" wrote.  A relative path means somewhere in that project, so
 * it is rooted there; an absolute one -- a tool or a pkg-config file
 * outside the tree, say -- already names exactly one place, and is
 * watched where it is.  Pasting it onto the project's directory
 * instead gives a path the normalizer quietly turns into a relative
 * one inside the project, which names nothing, and the $(wildcard)
 * every watched name goes through hides that: the build just never
 * reconfigures when the thing the line was written for changes. */
static void add_config_dep_from(const std::string& srcpath,
                                const std::string& dep)
{
    if (dep[0] == '/')
        add_config_dep(dep);
    else
        add_config_dep(srcpath + "/" + dep);
}

void project::process_line(const ptr& self,
                           const configfile_line& line,
                           std::set<std::string>& seen)
{
    const auto& processor = self->_processor;

    auto command = parse_line(line);
    if (command != NULL)
        processor->process(command);

    /* A CONFIG is read right where it appeared, so its lines land in
     * the middle of the file that asked for it. */
    while (true) {
        auto config = processor->take_pending_config();
        if (config == NULL)
            break;

        read_config(self, config, seen);
    }

    /* A CONFIG_DEPS is registered the same way and in the same place,
     * so that "test/glade-vm" means the same directory whichever of
     * the two commands wrote it: relative to the project whose
     * Configfile the line was in, not to wherever pconfigure was
     * started.  Drained after the CONFIGs above so that a family's own
     * executable Configfile can print its CONFIG_DEPS line itself --
     * which is the form that keeps the dependency next to the glob it
     * describes, rather than in the file that merely asked for it. */
    while (true) {
        auto dep = processor->take_pending_config_dep();
        if (dep.size() == 0)
            break;

        add_config_dep_from(processor->srcpath(), dep);
    }

    /* A subproject is read before the next line, so that the rest of
     * this Configfile can ask about what it builds. */
    while (true) {
        auto asked_by = command::ptr(NULL);
        auto base = processor->take_pending_subproject(asked_by);
        if (base.size() == 0)
            break;

        /* Copied out rather than kept, since the root context goes
         * on changing under the lines below and what is wanted later
         * is what the subproject was handed now. */
        auto handed_prefix = processor->root_context()->prefix;
        auto handed_cross_compile = processor->root_context()->cross_compile;

        auto child = read(base, processor, asked_by, seen);
        if (child == NULL)
            continue;
        self->_children.push_back(child);

        /* Told back once the subproject and everything under it has
         * been read all the way through, since any of their
         * Configfiles may have given a library a PREFIX or a
         * CROSS_COMPILE of its own.  Only a library still on what was
         * handed down is one a line below here could have reached by
         * being written above instead; a subproject that only groups
         * others, or whose libraries all say where they go, is left
         * out of it.  Each Configfile on the way down has already
         * been held to this same rule, so a library that agrees with
         * what this subproject was handed got it from here -- or says
         * the same thing itself, which splits from a later line just
         * as surely. */
        auto prefix_library = context::ptr(NULL);
        auto cross_compile_library = context::ptr(NULL);
        for (const auto& descendant: flatten(child)) {
            for (const auto& ctx: descendant->processor()->output_contexts()) {
                if (ctx->check_type({context_type::LIBRARY}) == false)
                    continue;
                if (prefix_library == NULL && ctx->prefix == handed_prefix)
                    prefix_library = ctx;
                if (cross_compile_library == NULL
                    && ctx->cross_compile == handed_cross_compile)
                    cross_compile_library = ctx;
            }
        }

        processor->subproject_was_read(child->base(),
                                       handed_prefix, prefix_library,
                                       handed_cross_compile,
                                       cross_compile_library);
    }
}

void project::read_file(const ptr& self,
                        const std::string& filename,
                        std::set<std::string>& seen)
{
    /* One of the files every project reads is being read as much as
     * one a CONFIG named, so a CONFIG of "../Configfile" from inside
     * it is the same cycle as a file naming itself. */
    auto normalized = file_utils::normalize_path(filename);

    /* A CONFIG -- or a "--config", which is read before any of these --
     * can name one of them before its turn comes, and then it is read
     * twice.  The only line to blame is that CONFIG, so the complaint
     * goes there; by the time the file's own turn comes nothing else
     * is reading it, and a complaint about one of its CONFIGs would
     * name that same line as both the repeat and the first reading. */
    auto found = self->_read.find(normalized);
    bool repeat = found != self->_read.end();
    if (repeat && found->second != NULL && self->_rereading == 0) {
        self->_processor->strictness().complain(
            strict_since::v0_13(),
            found->second->debug(),
            "CONFIG names " + normalized + ", which is one of the"
            " Configfiles every project reads anyway, so everything in"
            " it is read a second time when its own turn comes",
            "remove this CONFIG -- the file is read without one");
    }

    self->_reading.push_back(std::make_pair(normalized, command::ptr(NULL)));
    self->_read.insert(std::make_pair(normalized, command::ptr(NULL)));
    if (repeat)
        self->_rereading++;

    for (const auto& line: lines_from_file(self->_processor->srcpath(),
                                           filename))
        process_line(self, line, seen);

    if (repeat)
        self->_rereading--;
    self->_reading.pop_back();
}

void project::read_config(const ptr& self,
                          const command::ptr& config,
                          std::set<std::string>& seen)
{
    const auto& processor = self->_processor;

    /* The same two names config_lines() reads, spelled the one way
     * every other name of the file is, so that "../Configfile" from
     * Configfiles/ and the "./Configfile" read at the top are one
     * file.  Only the ones that are there count: a name with nothing
     * behind it reads nothing, and config_lines() has its own
     * complaint for a CONFIG where neither is. */
    auto names = std::vector<std::string>();
    for (const auto& name: std::vector<std::string>{
             processor->srcpath() + "/Configfiles/" + config->data(),
             processor->srcpath() + "/Configfile." + config->data()}) {
        struct stat st;
        if (stat(name.c_str(), &st) == 0)
            names.push_back(file_utils::normalize_path(name));
    }

    /* A file that is still being read can't be read again from inside
     * itself: its lines include this one, so it would get here again,
     * and so on until the stack runs out.  That used to be a SIGSEGV
     * with nothing printed, which is the least helpful thing a
     * Configfile mistake can come out as.  The complaint walks back
     * through the CONFIGs that got here, since the line that closes
     * a loop of several files is rarely the one that needs to go. */
    for (const auto& name: names) {
        size_t open = self->_reading.size();
        for (size_t i = 0; i < self->_reading.size(); ++i)
            if (self->_reading[i].first == name)
                open = i;
        if (open == self->_reading.size())
            continue;

        std::cerr << std::to_string(config->debug()) << "\n"
                  << "  error: CONFIG names " << name
                  << ", which is already being read -- reading it again"
                  << " would reach this line again, and never finish\n";
        for (size_t i = self->_reading.size(); i-- > open; ) {
            const auto& reading = self->_reading[i];
            if (reading.second != NULL)
                std::cerr << "  " << reading.first << " is being read because of "
                          << std::to_string(reading.second->debug()) << "\n";
            else
                std::cerr << "  " << reading.first << " is being read as one"
                          << " of the Configfiles every project reads\n";
        }
        std::cerr << "  remove this CONFIG, or move what both files need"
                  << " into a Configfile of its own that each of them"
                  << " CONFIGs and that CONFIGs neither of them\n";
        abort();
    }

    /* A file that has already been read is read again, because a
     * CONFIG is the manual's #include: its lines land wherever the
     * CONFIG is, so a file of options can mean something under each
     * of two targets.  But far more often it is the same line written
     * twice, or two Configfiles that each pull in one they share, and
     * then everything the file declares is declared twice -- which
     * used to be said only by the warning about a duplicate target,
     * blaming a line of the CONFIG'd file as a duplicate of itself
     * and never naming either CONFIG.  This names both. */
    bool repeat = false;
    for (const auto& name: names) {
        auto found = self->_read.find(name);
        if (found == self->_read.end())
            continue;

        repeat = true;
        if (self->_rereading > 0)
            break;

        auto before = (found->second != NULL)
            ? "for " + std::to_string(found->second->debug())
            : std::string("as one of the Configfiles every project reads");
        processor->strictness().complain(
            strict_since::v0_13(),
            config->debug(),
            "CONFIG names " + name + ", which was already read " + before
            + ", so everything in it is read a second time",
            "remove one of the two -- and if its lines really are meant to"
            " land in two places, give the second place a Configfile of its"
            " own, so that nothing is read twice");
        break;
    }

    for (const auto& name: names) {
        self->_reading.push_back(std::make_pair(name, config));
        self->_read.insert(std::make_pair(name, config));
    }
    if (repeat)
        self->_rereading++;

    for (const auto& line: config_lines(processor->srcpath(), config))
        process_line(self, line, seen);

    if (repeat)
        self->_rereading--;
    for (size_t i = 0; i < names.size(); ++i)
        self->_reading.pop_back();
}

project::ptr project::read(const command_processor::ptr& processor,
                           std::set<std::string>& seen,
                           const command::ptr& asked_by)
{
    auto out = std::make_shared<project>(processor->base(), processor,
                                         asked_by);

    /* The top of the run comes this way without passing the check in
     * the other read(), and is just as much a project that has been
     * read: a subproject that reaches back to it through a symlink is
     * this tree again, not another one.  Inserting a project's own
     * identity a second time changes nothing. */
    seen.insert(identity(processor->base()));

    /* Anything the command line asked for comes first, since that's
     * the order it was processed in.  Every one of them is taken off
     * the queue before any is read: reading a file drains the queue
     * after each of its lines, so a second "--config" left there would
     * be read from inside the first one's file, while that file is
     * still open -- which reads as a cycle, and "--config debugsym
     * --config debug" is nothing of the sort.  Each "--config" is a
     * sibling of the others, not nested in the one before it. */
    auto command_line = std::vector<command::ptr>();
    while (true) {
        auto config = processor->take_pending_config();
        if (config == NULL)
            break;

        command_line.push_back(config);
    }
    for (const auto& config: command_line)
        read_config(out, config, seen);

    /* A CONFIG_DEPS is registered the same way and in the same place,
     * so that "test/glade-vm" means the same directory whichever of
     * the two commands wrote it: relative to the project whose
     * Configfile the line was in, not to wherever pconfigure was
     * started.  Drained after the CONFIGs above so that a family's own
     * executable Configfile can print its CONFIG_DEPS line itself --
     * which is the form that keeps the dependency next to the glob it
     * describes, rather than in the file that merely asked for it. */
    while (true) {
        auto dep = processor->take_pending_config_dep();
        if (dep.size() == 0)
            break;

        add_config_dep_from(processor->srcpath(), dep);
    }

    /* A "--srcpath" is asked about before its Configfiles are read,
     * since a tree that isn't there has none and reads as an empty
     * project -- and again once they have been, for a SRCPATH one of
     * them wrote. */
    processor->check_srcpath();

    for (const auto& filename: std::vector<std::string>{
             processor->srcpath() + "/Configfiles/local",
             processor->srcpath() + "/Configfile.local",
             processor->srcpath() + "/Configfiles/main",
             processor->srcpath() + "/Configfile"})
        read_file(out, filename, seen);

    processor->check_srcpath();

    out->generate_targets();
    return out;
}

project::ptr project::read(const std::string& base,
                           const command_processor::ptr& parent,
                           const command::ptr& asked_by,
                           std::set<std::string>& seen)
{
    /* The path arrived normalized, and whether this is a pconfigure
     * project at all was decided before it got here: picking a build
     * system for a directory is what a SUBPROJECTS does, and only the
     * ones that turned out to be pconfigure projects come this way. */
    auto normalized = normalize_base(base);

    /* A project that two others both pull in is one project, and only
     * gets read once -- which is also what stops a project that
     * somehow reaches itself from recursing forever.  Which project a
     * directory is gets decided by the directory, though, not by how
     * the line spelled it: "vendor/a" and a symlink "a" to it are one
     * tree, and reading it under both names writes two Makefiles into
     * one object directory, each with its own rule for the same test
     * result, which a parallel "make check" then runs at once. */
    if (seen.insert(identity(normalized)).second == false)
        return NULL;

    auto processor = std::make_shared<command_processor>(
        normalized,
        parent->root_context(),
        parent->vendored_in_run());
    return read(processor, seen, asked_by);
}

std::set<std::string> project::reachable(void) const
{
    auto out = std::set<std::string>{_base};
    for (const auto& child: _children)
        for (const auto& base: child->reachable())
            out.insert(base);
    return out;
}

std::vector<project::ptr> project::flatten(const ptr& root)
{
    auto out = std::vector<ptr>{root};
    for (const auto& child: root->_children)
        for (const auto& descendant: flatten(child))
            out.push_back(descendant);
    return out;
}

debug_info::ptr project::written_by(const std::string& name) const
{
    auto found = _written_by.find(name);
    if (found == _written_by.end())
        return NULL;
    return found->second;
}

void project::generate_targets(void)
{
    /* Which directories this project actually puts a library in.
     * That's a set rather than a single answer because a LIBDIR
     * means one project can have more than one of them, and a target
     * written above that line has nothing to do with what came out
     * below it. */
    auto lib_dirs = std::set<std::string>();
    for (const auto& context: _processor->output_contexts())
        if (context->check_type({context_type::LIBRARY}) == true)
            lib_dirs.insert(context->lib_dir);

    /* Every context gets told, not just the ones a Configfile named
     * outright: a test is built like a binary, by a context that
     * hangs off the target it tests, and it gets linked the same way
     * everything else does. */
    std::function<void(const context::ptr&)> mark =
        [&](const context::ptr& ctx)
        {
            ctx->lib_dir_built = lib_dirs.find(ctx->lib_dir) != lib_dirs.end();

            /* Asked of the project rather than read off the line,
             * because the answer belongs to the project: a Configfile
             * that says it at the bottom has said the same thing as
             * one that says it at the top, and the contexts above
             * that line have already been built by the time it is
             * read. */
            ctx->autoreconfigure = _processor->autoreconfigure();

            for (const auto& child: ctx->children)
                mark(child);
        };

    for (const auto& context: _processor->output_contexts())
        mark(context);

    /* A vendored tree's rules belong to this project: the tree
     * already has a Makefile and it's the tree's own, so there's
     * nowhere else for them to go. */
    for (const auto& vendored: _processor->vendored())
        for (const auto& target: vendored->targets(_processor->vendored(),
                                                   _base))
            _targets.push_back(target);

    /* What each target this project builds is going to be called,
     * which is the only way to notice that two of them are going to
     * be called the same thing.  The name alone isn't enough: a
     * LIBDIR between two LIBRARIES lines makes two libraries with one
     * name and two homes, which is a thing somebody meant. */
    auto by_output = std::map<std::string, context::ptr>();
    auto scratch_claims = std::map<std::string,
                                   std::pair<context::ptr, std::string>>();

    /* A GENERATE writes its output while its targets are being worked
     * out, and a source's targets are worked out by scanning it for
     * the headers that are on disk at that moment.  So every GENERATE
     * is asked first, whichever line it was written on.  One written
     * below the BINARIES whose source includes its output used to be
     * generated only after that source had been scanned, which left
     * the object with no dependency on the header -- an edited input
     * regenerated it and nothing recompiled -- and a second
     * pconfigure, finding the header the first had left behind, wrote
     * a different Makefile.  Refusing the line would have been the
     * other way out, but it would also have refused the generator
     * binary shape, where the tool a GENERATE runs is a BINARIES
     * written above it.  Only the generating moves: the rules still
     * come out in the order the Configfile wrote them. */
    auto generated = std::map<context::ptr, std::vector<makefile::target::ptr>>();
    for (const auto& context: _processor->output_contexts()) {
        if (context->check_type({context_type::GENERATE}) == false)
            continue;

        /* Before this GENERATE's generator runs rather than after: a
         * name that collides with another GENERATE's scratch file is
         * refused, and a refused line should not have already had its
         * generator write through the other's temporary first. */
        check_generate_names(context, scratch_claims);

        auto language = pick_language(context->languages, context);
        generated[context] = language->targets(context);
    }

    /* A HEADERSRC is the other way a project makes a header for
     * itself, and it is asked here for the same reason: what it makes
     * has to be known before any source is.  Its copy is also made
     * while its targets are worked out, when the header isn't there
     * yet, so a scan below it finds the copy wherever the line was
     * written. */
    for (const auto& context: _processor->output_contexts()) {
        if (context->check_type({context_type::HEADER}) == false)
            continue;

        check_header_copy(context);

        auto language = pick_language(context->languages, context);
        generated[context] = language->targets(context);
    }

    /* What those make, for a source to read.  Under AUTORECONFIGURE
     * it is pdeps that works out which headers a source reads, while
     * the build runs, and after a "make clean" or a deleted object
     * directory these are exactly the headers that aren't there when
     * it asks: a scan that only believes the disk leaves them out of
     * the fragment, nothing then makes them before the object that
     * reads them is compiled, and once they are back nothing
     * recompiles that object when they change.  So pdeps is told
     * they are coming.
     *
     * Every target with a recipe, rather than only the ones that look
     * like headers: anything a GENERATE writes can be #included, and a
     * name nothing includes is a name nothing ever asks about.  An
     * install target is a copy outside the tree, which is no business
     * of a scan inside it.
     *
     * Kept sorted, because it ends up in every context file pdeps
     * reads and the map above is in whatever order the pointers came
     * out in: a list that comes out shuffled is a context file that
     * changes on every configure, and every fragment behind it worked
     * out again for nothing. */
    auto made = std::set<std::string>();
    for (const auto& pair: generated)
        for (const auto& target: pair.second) {
            if (target->cmds().size() == 0)
                continue;
            if (target->has_global_target(makefile::global_targets::INSTALL)
                || target->has_global_target(
                       makefile::global_targets::UNINSTALL))
                continue;
            made.insert(file_utils::normalize_path(target->name()));
        }
    auto build_made = std::vector<std::string>(made.begin(), made.end());

    std::function<void(const context::ptr&)> stamp_build_made =
        [&](const context::ptr& ctx)
        {
            ctx->build_made = build_made;
            for (const auto& child: ctx->children)
                stamp_build_made(child);
        };

    for (const auto& context: _processor->output_contexts())
        stamp_build_made(context);

    for (const auto& context: _processor->output_contexts()) {
        if (context->debug == true)
            std::cerr << "Building Context: " << context->cmd->data() << "\n";

        check_target_shape(context, by_output);

        auto language = pick_language(context->languages, context);
        auto found_generated = generated.find(context);
        auto targets = (found_generated != generated.end())
            ? found_generated->second
            : language->targets(context);
        for (const auto& target: targets) {
            auto found = _by_name.find(target->name());
            if (found == _by_name.end()) {
                if (context->debug == true)
                    std::cerr << "  target: " << target->name() << "\n";
                _targets.push_back(target);
            } else if (!same_recipe(found->second, target)) {
                /* Two different rules for one file.  The ways of getting
                 * here that anybody has found are complained about
                 * earlier, naming both lines -- two BINARIES that come
                 * out in one place get a warning just above this loop,
                 * or an error under STRICT -- so this is what is left
                 * when that warning was not enough, and the backstop
                 * for the next way nobody has found yet.
                 *
                 * It goes to stderr, and names the line being read and
                 * the file that two rules write, because abort() does
                 * not flush stdout: the same sentence on std::cout was,
                 * whenever stdout was a file or a pipe, an exit status
                 * of 134 and nothing else whatsoever. */
                std::cerr << std::to_string(context->cmd->debug()) << "\n"
                          << "  error: Mismatched recipe for targets with"
                          << " same name: two different rules write '"
                          << target->name() << "'\n"
                          << "  give one of the two things that write it a"
                          << " different name\n";
                abort();
            }
            _by_name[target->name()] = target;
            if (_written_by.find(target->name()) == _written_by.end())
                _written_by[target->name()] = context->cmd->debug();

            /* Only the language that wrote this recipe knows how to
             * read it, so it's the one that says what this target
             * offers and what it wants.  Matching those up is left
             * until every project's targets are known. */
            for (const auto& name: language->provides(target))
                _provided.push_back(makefile::capability(name, target->name()));
            for (const auto& name: language->needs(target))
                _needed.push_back(makefile::capability(name, target->name()));
        }
    }

    /* Every suite this project has is declared by the time the last
     * Configfile line has been read, which is all this needs. */
    check_test_suites();

    /* Now that every test in this project has a name, and not before:
     * a DEPTESTS is allowed to name a test written further down the
     * Configfile than the line that waits for it. */
    check_test_order();

    /* And for the same reason again: a test named after another's
     * scratch directory can be written above the test it collides
     * with. */
    check_test_scratch();

    /* Same reason: what an AUTODEPS = false was worth depends on
     * everything it reached, and one line reaches as far down the
     * file as the target it was written on goes. */
    check_autodeps();
}

std::map<std::string, std::vector<std::string>>
project::test_suite_members(void) const
{
    auto tests = this->tests();

    /* The tests that named each suite themselves.  Every suite gets
     * an entry whether or not anything joined it, since the rules
     * that come out of this are what a name means. */
    auto named = std::map<std::string, std::set<std::string>>();
    for (const auto& suite: _processor->test_suites())
        named[suite->name()] = std::set<std::string>();

    for (const auto& pair: tests) {
        const auto& ctx = pair.second;
        if (ctx->test_suite_name.size() == 0)
            continue;

        named[ctx->test_suite_name].insert(pair.first);
    }

    /* ... plus everything in the suites each one includes, at any
     * depth.  Two suites that include each other are two names for
     * one set of tests, which is a strange thing to write and a
     * perfectly clear thing to mean, so the walk keeps track of where
     * it has been rather than refusing to go. */
    auto members = std::map<std::string, std::set<std::string>>();

    std::function<void(const std::string&,
                       std::set<std::string>&,
                       std::set<std::string>&)> include =
        [&](const std::string& name,
            std::set<std::string>& out,
            std::set<std::string>& seen)
        {
            if (seen.insert(name).second == false)
                return;

            for (const auto& member: named[name])
                out.insert(member);

            auto suite = _processor->test_suite_named(name);
            if (suite == NULL)
                return;

            for (const auto& included: suite->includes())
                include(included->data(), out, seen);
        };

    for (const auto& suite: _processor->test_suites()) {
        auto seen = std::set<std::string>();
        members[suite->name()] = std::set<std::string>();
        include(suite->name(), members[suite->name()], seen);
    }

    /* ... plus whatever the tests in it wait for, plus every test
     * that was written without a suite and could run here.
     *
     * Both of those grow the set, and each can feed the other, so
     * they go around together until nothing moves.  A test that waits
     * for one that has just joined is a test that has just become
     * runnable here, and asking the two questions once each in some
     * order would answer whichever one went second against a set that
     * was still growing. */
    for (auto& pair: members) {
        auto growing = true;
        while (growing == true) {
            growing = false;

            /* A DEPTESTS is a prerequisite, so asking make for a
             * suite runs every test its tests wait for whether or not
             * the suite claims them.  Leaving one out of the report
             * wouldn't stop any of that happening; it would just stop
             * it being reported. */
            for (const auto& member: std::set<std::string>(pair.second)) {
                auto found = tests.find(member);
                if (found == tests.end())
                    continue;

                for (const auto& dep: found->second->based_dep_tests())
                    if (pair.second.insert(dep).second == true)
                        growing = true;
            }

            /* A test written without a suite is a test with nothing
             * to say about where it can run, so it runs everywhere --
             * except that a test which waits for one it can't run
             * beside is a test that can't run there either.  What it
             * waits for is the only thing about it that ever named a
             * suite, so it's the only thing there is to go on. */
            for (const auto& test: tests) {
                if (test.second->test_suite_name.size() > 0)
                    continue;
                if (pair.second.find(test.first) != pair.second.end())
                    continue;

                auto runnable = true;
                for (const auto& dep: test.second->based_dep_tests())
                    if (pair.second.find(dep) == pair.second.end())
                        runnable = false;

                if (runnable == false)
                    continue;

                pair.second.insert(test.first);
                growing = true;
            }
        }
    }

    auto out = std::map<std::string, std::vector<std::string>>();
    for (const auto& pair: members)
        out[pair.first] = std::vector<std::string>(pair.second.begin(),
                                                   pair.second.end());
    return out;
}

std::map<std::string, std::vector<std::string>>
project::aggregate_test_suite_members(const std::vector<ptr>& aggregated)
{
    /* What each project put in each suite when asked on its own,
     * gathered under the one name make will know it by.  Every suite
     * any of them declared has an entry, empty ones included: the
     * rule that runs nothing is still a rule, and it is still the
     * answer to what the name means. */
    auto named = std::map<std::string, std::set<std::string>>();
    for (const auto& project: aggregated)
        for (const auto& suite: project->test_suite_members())
            named[suite.first].insert(suite.second.begin(),
                                      suite.second.end());

    /* Which suites each one includes, gathered the same way.  A
     * suite two projects declared is one suite, so it includes
     * whatever either of them said it includes -- the alternative is
     * a name whose meaning depends on which directory you read, and
     * there is only one rule to run. */
    auto includes = std::map<std::string, std::set<std::string>>();
    for (const auto& project: aggregated)
        for (const auto& suite: project->processor()->test_suites())
            for (const auto& include: suite->includes())
                includes[suite->name()].insert(include->data());

    /* The same walk each project already did over its own suites,
     * over all of them at once.  Two suites that include each other
     * are two names for one set of tests, so it keeps track of where
     * it has been rather than refusing to go.
     *
     * Nothing grows here except by inclusion, and that is deliberate:
     * the other three ways into a suite are questions about one
     * project's tests.  A DEPTESTS names a test of the same target,
     * so what waits for what never crosses a project boundary, and a
     * test written without a suite joins the suites of the project
     * that wrote it -- a project that never declared a suite has no
     * opinion about which of its tests could run in it.  Both were
     * answered before this was called, and a set that arrives from
     * another project arrives already closed. */
    auto members = std::map<std::string, std::set<std::string>>();

    std::function<void(const std::string&,
                       std::set<std::string>&,
                       std::set<std::string>&)> include =
        [&](const std::string& name,
            std::set<std::string>& out,
            std::set<std::string>& seen)
        {
            if (seen.insert(name).second == false)
                return;

            for (const auto& member: named[name])
                out.insert(member);

            auto found = includes.find(name);
            if (found == includes.end())
                return;

            for (const auto& included: found->second)
                include(included, out, seen);
        };

    for (const auto& pair: named) {
        auto seen = std::set<std::string>();
        members[pair.first] = std::set<std::string>();
        include(pair.first, members[pair.first], seen);
    }

    auto out = std::map<std::string, std::vector<std::string>>();
    for (const auto& pair: members)
        out[pair.first] = std::vector<std::string>(pair.second.begin(),
                                                   pair.second.end());
    return out;
}

std::map<std::string, context::ptr> project::tests(void) const
{
    auto out = std::map<std::string, context::ptr>();

    std::function<void(const context::ptr&)> gather =
        [&](const context::ptr& ctx)
        {
            if (ctx->check_type({context_type::TEST}) == true)
                out[ctx->check_target()] = ctx;

            for (const auto& child: ctx->children)
                gather(child);
        };

    for (const auto& ctx: _processor->output_contexts())
        gather(ctx);

    return out;
}

/* The suites a project has, said the way a complaint about a name
 * that isn't one of them wants to say it. */
static void print_suites(const std::vector<test_suite::ptr>& suites)
{
    if (suites.size() == 0) {
        std::cerr << "  this project declares no test suites at all: a"
                  << " TEST_SUITES line is what makes one\n";
        return;
    }

    if (suites.size() == 1) {
        std::cerr << "  the only suite here is '"
                  << suites[0]->name() << "'\n";
        return;
    }

    std::cerr << "  the suites here are:";
    for (const auto& suite: suites)
        std::cerr << " '" << suite->name() << "'";
    std::cerr << "\n";
}

void project::check_test_suites(void) const
{
    for (const auto& suite: _processor->test_suites()) {
        for (const auto& include: suite->includes()) {
            if (_processor->test_suite_named(include->data()) != NULL)
                continue;

            /* What make would do with this is nothing at all: the
             * suite that was named has no tests because it has no
             * existence, so the rule that runs it comes out empty and
             * the tests somebody meant to include quietly don't run.
             * A suite that reports "no tests" is exactly what a suite
             * nobody has joined yet looks like, so there is nothing
             * downstream that could tell the two apart. */
            std::cerr << std::to_string(include->debug()) << "\n"
                      << "  error: "
                      << std::to_string(include->type())
                      << " names '" << include->data()
                      << "', which is no test suite of this project\n"
                      << "  it names a suite of this same project,"
                      << " spelled the way that suite's own TEST_SUITES"
                      << " line spelled it\n";

            print_suites(_processor->test_suites());
            abort();
        }
    }

    for (const auto& pair: tests()) {
        const auto& ctx = pair.second;
        if (ctx->test_suite_name.size() == 0)
            continue;
        if (_processor->test_suite_named(ctx->test_suite_name) != NULL)
            continue;

        /* The same silence as above, arrived at from the other side:
         * a test that joined a suite nobody declared is a test in no
         * suite, and a suite with one fewer test in it is not
         * something any report could notice. */
        std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                  << "  error: "
                  << std::to_string(ctx->cmd->type())
                  << " names the suite '" << ctx->test_suite_name
                  << "', which is no test suite of this project\n"
                  << "  a test joins a suite of this same project,"
                  << " spelled the way that suite's own TEST_SUITES line"
                  << " spelled it\n";

        print_suites(_processor->test_suites());
        abort();
    }

    const auto& fallback = _processor->default_test_suite();
    if (fallback.size() > 0
        && _processor->test_suite_named(fallback) == NULL) {
        /* This one has a symptom, and it's the worst of the three: a
         * "make check" that runs nothing at all and says everything
         * passed. */
        std::cerr << std::to_string(_processor->default_test_suite_cmd()->debug())
                  << "\n"
                  << "  error: DEFAULT_TEST_SUITE names '" << fallback
                  << "', which is no test suite of this project\n"
                  << "  it names a suite of this same project, spelled the"
                  << " way that suite's own TEST_SUITES line spelled it\n"
                  << "  leave the line out entirely for a \"make check\""
                  << " that runs every test\n";

        print_suites(_processor->test_suites());
        abort();
    }
}

/* The suites of a build that have tests in them, said the way a
 * complaint about one that hasn't wants to say it.  Which suites
 * exist isn't the question here -- the name in hand is one of them --
 * so what's worth printing is which of them would have run
 * something. */
static void print_populated_suites(
    const std::map<std::string, size_t>& members)
{
    auto populated = std::vector<std::string>();
    for (const auto& pair: members)
        if (pair.second > 0)
            populated.push_back(pair.first);

    if (populated.size() == 0) {
        std::cerr << "  no suite of this build has a test in it: a"
                  << " TESTS[$name] or TESTSRC[$name] line is what puts"
                  << " one there\n";
        return;
    }

    if (populated.size() == 1) {
        std::cerr << "  the only suite here with tests in it is '"
                  << populated[0] << "'\n";
        return;
    }

    std::cerr << "  the suites here with tests in them are:";
    for (const auto& name: populated)
        std::cerr << " '" << name << "'";
    std::cerr << "\n";
}

void project::check_default_test_suite(const std::vector<ptr>& aggregated) const
{
    const auto& fallback = _processor->default_test_suite();
    if (fallback.size() == 0)
        return;

    /* How many tests each suite of this build runs, counted across
     * every project whose results this one's Makefile is responsible
     * for.  A suite that is empty here can still be full a directory
     * down -- two projects that declare a suite of one name have one
     * suite once there is one rule to run it -- so asking this
     * project on its own would refuse a build that runs plenty. */
    auto members = std::map<std::string, size_t>();
    for (const auto& suite: aggregate_test_suite_members(aggregated))
        members[suite.first] = suite.second.size();

    if (members[fallback] > 0)
        return;

    /* A suite nothing joined is a perfectly good thing to declare:
     * the name is a promise about what "make check-$name" means, and
     * an empty one keeps it by running nothing.  Being the suite that
     * "make check" means is the one place that stops being true,
     * because the two words nobody has to be told to type stop
     * reaching any test the project has and start reporting that
     * every one of them passed.
     *
     * That symptom is why a DEFAULT_TEST_SUITE naming a suite this
     * project never declared is fatal.  Spelling the name right is no
     * comfort to whoever reads the green report, so it is fatal
     * here too. */
    std::cerr << std::to_string(_processor->default_test_suite_cmd()->debug())
              << "\n"
              << "  error: DEFAULT_TEST_SUITE names '" << fallback
              << "', which no test of this build is in\n"
              << "  \"make check\" would run no tests at all and report"
              << " that they all passed\n"
              << "  put a test in it with TESTS[" << fallback
              << "] or TESTSRC[" << fallback
              << "], or name a suite that already has one\n"
              << "  leave the line out entirely for a \"make check\""
              << " that runs every test\n";

    print_populated_suites(members);
    abort();
}

/* The names a complaint about a project that declared no suite wants
 * to offer: every suite this build has, since those are the names a
 * TEST_SUITES line down there could usefully write. */
static void print_build_suites(
    const std::map<std::string, std::vector<std::string>>& members)
{
    std::cerr << "  the suites of this build are:";
    for (const auto& pair: members)
        std::cerr << " '" << pair.first << "'";
    std::cerr << "\n";
}

void project::check_aggregated_test_suites(
    const std::vector<ptr>& aggregated) const
{
    /* Only a build whose "make check" means a suite.  Without a
     * DEFAULT_TEST_SUITE those two words mean every test the build
     * has, so a project that joined nothing has lost nothing: its
     * tests still run, and the only thing it cannot be is asked for
     * by a suite's name.  That is the shape every project had before
     * suites existed, and it is still a good one. */
    const auto& fallback = _processor->default_test_suite();
    if (fallback.size() == 0)
        return;

    for (const auto& project: aggregated) {
        /* A project that declared a suite has had this thought, and
         * which of its tests go in which of them is its own business.
         * A project of nothing but hours-long harnesses belongs in
         * "overnight" and in no "smoke", so a configure that refused
         * that would be refusing an answer rather than a mistake.
         *
         * Never having said anything is the mistake, and it is a
         * different one: a project with no suites has its tests in no
         * suite at all, so the two words nobody has to be told to
         * type reach none of them. */
        if (project->processor()->test_suites().size() > 0)
            continue;

        /* A project with no tests is outside every suite for a reason
         * that has nothing to do with suites, and every vendored tree
         * a build pulls in looks exactly like that. */
        const auto tests = project->tests();
        if (tests.size() == 0)
            continue;

        /* Fatal, for the reason the rest of this family is fatal: what
         * goes wrong downstream is a green report, and a green report
         * is no warning at all.  There is deliberately no Configfile
         * line quoted, because the defect is a line that isn't there
         * -- so the complaint names the directory to write it in.
         *
         * Which is also why this is not a strict::complain().  That
         * mechanism is for a line pconfigure used to accept and has
         * to go on accepting, and it hangs its warning off the line;
         * there is no line here.  Nor is there an older project to
         * stay compatible with: a build with no DEFAULT_TEST_SUITE
         * returned above, and nothing predating dce1a9a
         * ("pconfigure: Choose what \"make check\" runs with
         * DEFAULT_TEST_SUITE") has one.  So every build this can
         * reach was written after suites existed, and in those the
         * silence is the bug rather than the behaviour. */
        const auto where = project->base().size() > 0
            ? "'" + project->base() + "'"
            : std::string("this project");

        std::cerr << "error: " << where << " has "
                  << std::to_string(tests.size()) << " test"
                  << (tests.size() == 1 ? "" : "s")
                  << " and declares no test suite, so \"make check\""
                  << " here runs none of them\n"
                  << "  \"make check\" here means the '" << fallback
                  << "' suite, and a suite collects nothing from a"
                  << " project that never named it -- while a \"make"
                  << " check\" run in there runs every one of those"
                  << " tests and reports that they passed, which is"
                  << " where anybody would go to find out whether they"
                  << " ran\n"
                  << "  write a TEST_SUITES line in that project's own"
                  << " Configfile for each suite its tests belong in,"
                  << " spelled the way this build spells it\n"
                  << "  one line can be enough: an INCLUDE_TEST_SUITES"
                  << " is resolved over the whole build, so a test that"
                  << " joins a suite down there does arrive in one that"
                  << " includes it up here -- what inclusion cannot do is"
                  << " give a suite to a project that named none, which is"
                  << " why this has to be reported rather than inferred\n";

        print_build_suites(aggregate_test_suite_members(aggregated));
        abort();
    }
}

void project::check_phony_suite_goals(const std::vector<ptr>& aggregated) const
{
    /* Only this project's own PHONYs: they are the ones that land in
     * this project's Makefile with nothing in front of them.  One from
     * a subproject is under that subproject's directory here, and is
     * asked about when the subproject takes its own turn at this,
     * which is the Makefile it lands in bare. */
    for (const auto& ctx: _processor->output_contexts()) {
        if (ctx->type != context_type::PHONY)
            continue;

        /* As make reads it, which is without any "./" on the front:
         * "./check-quick" is the suite's goal as much as the bare
         * spelling is. */
        const auto& written = ctx->cmd->data();
        const auto name = string_utils::make_target_name(written);

        auto suite = std::string();
        for (const auto& prefix: {"check-", "report-"}) {
            if (name.compare(0, strlen(prefix), prefix) == 0)
                suite = name.substr(strlen(prefix));
        }
        if (suite.size() == 0)
            continue;

        /* Any suite this Makefile runs, not only the ones this project
         * declared: a suite a subproject declares gets its
         * "check-<name>" rule written up here too, since this is the
         * Makefile that gets asked for it.  Found by its line rather
         * than by its members, because the line is what the complaint
         * has to point at as well as the PHONY's. */
        test_suite::ptr declared = nullptr;
        for (const auto& project: aggregated) {
            declared = project->processor()->test_suite_named(suite);
            if (declared != nullptr)
                break;
        }
        if (declared == nullptr)
            continue;

        /* The same collision refuse_goal_name() turns down for "clean"
         * and the rest, with a name that only becomes a goal once a
         * suite is declared -- so it is asked here, once every
         * Configfile has been read, rather than at either line: the
         * suite can come after the PHONY, or from a subproject that
         * wasn't read yet.  Merged, "make check-<suite>" would build
         * whatever the PHONY stands for on top of running the suite,
         * and asking for the PHONY by name would run the suite. */
        std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                  << "  error: PHONY can't be called '" << written
                  << "': ";
        if (name != written)
            std::cerr << "make reads that as '" << name << "', which ";
        else
            std::cerr << "that ";
        std::cerr << "is the goal pconfigure writes for the test"
                  << " suite '" << suite << "'\n"
                  << "  " << std::to_string(declared->cmd()->debug())
                  << " declares that suite\n"
                  << "  make would read the two as one rule, so the"
                  << " suite would also build whatever this PHONY stands"
                  << " for, and asking for the PHONY would also run the"
                  << " suite\n"
                  << "  give the PHONY a name of its own, after what its"
                  << " tests exercise -- 'integration', say\n";
        abort();
    }
}

void project::check_bootstrap(const std::vector<ptr>& everyone) const
{
    const auto& srcpath = _processor->bootstrap();
    if (srcpath.size() == 0)
        return;

    /* Spelled the same way the Makefile spells it, because the
     * question is whether the thing that Makefile runs is a thing
     * this build knows how to produce. */
    const auto wanted = srcpath + "bin/pconfigure";

    for (const auto& other: everyone) {
        if (other->_base != srcpath)
            continue;

        for (const auto& target: other->_targets)
            if (target->name() == wanted)
                return;
    }

    std::cerr << std::to_string(_processor->bootstrap_cmd()->debug()) << "\n"
              << "  error: nothing in this build produces '" << wanted
              << "'\n"
              << "  that is the pconfigure the committed Makefile runs,"
              << " so the tree named here has to be one whose own"
              << " Configfiles build it\n"
              << "  a vendored pconfigure is pconfigure's source tree"
              << " checked out whole; a directory above or below it"
              << " gets this\n";
    abort();
}

void project::check_distclean_spares_subprojects(
    const std::vector<ptr>& projects) const
{
    /* Asked of this project's own "make distclean" rather than only
     * the one at the top of the run, because a subproject's Makefile
     * is one somebody can walk into and run distclean in -- and what
     * that removes is its own output directories and those of
     * everything below it, which is exactly "projects". */
    const auto dirs = distclean_dirs(projects);

    for (const auto& project: projects) {
        for (const auto& named: project->_processor->named_subprojects()) {
            /* Spelled without the trailing '/' that a project's
             * directory carries, which is how inside() wants it and
             * how the directory it's being compared to is spelled in
             * the message. */
            auto tree = file_utils::normalize_path(named.first);
            while (tree.size() > 1 && tree[tree.size() - 1] == '/')
                tree.pop_back();

            /* And the directory it really is, because the text is
             * only half of what the recipe acts on.  A "dep" that is
             * a symlink to "lib/dep" reads as a name nowhere near
             * "lib", but "rm -rf 'lib'" removes the checkout all the
             * same and leaves the link dangling.  This is the same
             * second question the object directory rule asks where
             * the SUBPROJECTS line is read, for the same reason, and
             * like that one it resolves both sides: a "lib" that is
             * itself a link to somewhere above the tree sends the
             * libraries into the checkout, which is just as much
             * output landing on somebody's sources.
             *
             * Both of these are "" for a path that doesn't exist yet,
             * which is fine to say nothing about: a directory that
             * isn't there has nothing in it for distclean to take,
             * and a tree that isn't there is complained about by
             * whatever went looking for its Configfile. */
            auto real_tree = file_utils::real_directory(tree);

            for (const auto& pair: dirs) {
                auto dir = file_utils::normalize_path(pair.first);

                /* What to say the tree is, which for a match on the
                 * text is just its name, and for a match through a
                 * symlink has to show where it went or the message
                 * reads as plainly false. */
                auto what = std::string();
                auto where = dir;
                if (file_utils::inside(tree, dir) == true) {
                    what = "'" + tree + "' is";
                } else {
                    auto real_dir = file_utils::real_directory(dir);
                    if (real_tree.size() == 0 || real_dir.size() == 0)
                        continue;
                    if (file_utils::inside(real_tree, real_dir) == false)
                        continue;
                    what = "'" + tree + "' resolves to '" + real_tree
                        + "', which is";
                    where = real_dir;
                }

                /* A LIBDIR is the one of these a Configfile can move,
                 * so it's the one worth suggesting moving.  The rest
                 * are named after the project and not up for
                 * discussion: the tree is what has to go somewhere
                 * else. */
                std::cerr << std::to_string(named.second->debug()) << "\n"
                          << "  error: " << what << " inside '" << where
                          << "', " << pair.second << "\n"
                          << "  'make distclean' is an 'rm -rf' of '" << dir
                          << "' -- so a tree checked out in there is one"
                          << " distclean away from being gone, and nothing"
                          << " about the recipe says so\n"
                          << "  check the tree out somewhere this build"
                          << " doesn't write";
                if (pair.second == "where libraries go")
                    std::cerr << ", or send the libraries somewhere else"
                              << " with a line like 'LIBDIR = libs'";
                std::cerr << "\n";
                abort();
            }
        }
    }
}

/* A directory "make distclean" removes, spelled the way the recipe
 * spells it and resolved the way rm will reach it, along with what
 * the directory is for.  Resolved once, here, rather than once for
 * every file asked about: a run that reads a few thousand headers
 * would otherwise ask the filesystem the same question a few thousand
 * times over. */
struct distclean_dir {
    std::string dir;
    std::string real;
    std::string role;
};

static std::vector<distclean_dir>
resolved_distclean_dirs(const std::map<std::string, std::string>& dirs)
{
    auto out = std::vector<distclean_dir>();
    for (const auto& pair: dirs) {
        auto dir = file_utils::normalize_path(pair.first);
        out.push_back(distclean_dir{dir,
                                    file_utils::real_directory(dir),
                                    pair.second});
    }
    return out;
}

/* Where "make distclean" would take a file from, if anywhere: the
 * directory it removes, what that directory is for, and how to say
 * the file got there.  "found" is false for a file it leaves alone.
 *
 * Asked of the file's text and then of the directory it is in with
 * its symlinks resolved, because rm follows a symlink it meets
 * partway along a path: a "src" that links to "lib/src" is a source
 * tree "rm -rf 'lib'" removes, whatever its name says.  The same
 * second question the SUBPROJECTS rule asks, resolving both sides for
 * the same reason.  A directory that isn't there resolves to "", and
 * has nothing in it to lose.  "resolved" remembers the answer for
 * each directory a file has been in, for the same reason the
 * directories themselves are resolved only once. */
struct distclean_taker {
    bool found;
    std::string what;
    std::string where;
    std::string dir;
    std::string role;
};

static distclean_taker
distclean_takes(const std::string& path,
                const std::vector<distclean_dir>& dirs,
                bool skip_object_dirs,
                std::map<std::string, std::string>& resolved)
{
    auto file = file_utils::normalize_path(path);
    auto slash = file.rfind('/');
    auto parent = (slash == std::string::npos)
        ? std::string(".")
        : file.substr(0, slash);
    auto name = (slash == std::string::npos)
        ? file
        : file.substr(slash + 1);

    auto found = resolved.find(parent);
    if (found == resolved.end())
        found = resolved.emplace(parent,
                                 file_utils::real_directory(parent)).first;
    const auto& real_parent = found->second;

    for (const auto& dir: dirs) {
        if (skip_object_dirs == true && dir.role == "the object directory")
            continue;

        if (file_utils::inside(file, dir.dir) == true)
            return distclean_taker{true, "'" + file + "' is", dir.dir,
                                   dir.dir, dir.role};

        if (real_parent.size() == 0 || dir.real.size() == 0)
            continue;
        if (file_utils::inside(real_parent, dir.real) == false)
            continue;
        return distclean_taker{true,
                               "'" + file + "' resolves to '" + real_parent
                               + "/" + name + "', which is",
                               dir.real, dir.dir, dir.role};
    }

    return distclean_taker{false, "", "", "", ""};
}

/* The rest of what is said about a file distclean would take, which
 * is the same whichever way the file was found. */
static void explain_distclean_takes(const distclean_taker& taken)
{
    std::cerr << "  'make distclean' is an 'rm -rf' of '" << taken.dir
              << "', because everything in there is output"
              << " this build can write again -- and a source"
              << " is the one thing it can't, so this file is"
              << " one distclean away from being gone\n"
              << "  keep the sources somewhere this build"
              << " doesn't write, like a 'src' directory and"
              << " 'SRCDIR = src'";
    if (taken.role == "where libraries go")
        std::cerr << ", or send the libraries somewhere else"
                  << " with a line like 'LIBDIR = libs'";
    std::cerr << "\n";
}

void project::check_distclean_spares_sources(
    const std::vector<ptr>& projects,
    const std::vector<ptr>& run) const
{
    /* Everything "make distclean" removes is removed whole, by an
     * "rm -rf" of the directory and nothing finer, because everything
     * in there is supposed to be output this build can write again.
     * A source is the one thing it can't write again.
     *
     * Refused rather than spared.  Sparing it would turn the "rm -rf"
     * of a directory into a walk that removes everything in there but
     * a list of names, which is a recipe that has to be exactly right
     * about every file a directory holds and fails by deleting
     * somebody's work -- and it would still leave sources sharing a
     * directory with the output the rest of the build writes, where
     * a binary called "main" in "bin" is one rule away from a
     * "bin/main" somebody wrote.  Moving the sources, or the
     * libraries, is a one-line edit with none of that. */
    const auto dirs = resolved_distclean_dirs(distclean_dirs(projects));
    auto resolved = std::map<std::string, std::string>();

    /* The files a Configfile line names outright come first, because
     * that line is the one to point at: it is the one to change. */
    for (const auto& project: projects) {
        for (const auto& read: project->_processor->read_sources()) {
            auto taken = distclean_takes(read.first, dirs, false, resolved);
            if (taken.found == false)
                continue;

            std::cerr << std::to_string(read.second->debug()) << "\n"
                      << "  error: " << taken.what << " inside '"
                      << taken.where << "', " << taken.role << "\n";
            explain_distclean_takes(taken);
            abort();
        }
    }

    /* Then every file the build reads that no line names: a header a
     * source includes, a file a script pastes in, whatever else a
     * language found by reading what it was handed.  The languages
     * have already said what those are, as the prerequisites of the
     * rules they wrote that nothing in the Makefile builds -- which
     * is the one list that has all of them, whichever language found
     * them and however.  A "lib/" of headers beside a "SRCDIR = ."
     * source gets here without a single line saying "lib/", so asking
     * only of what the lines name misses the very layout this is
     * about.
     *
     * Only for a file pconfigure found, which under AUTORECONFIGURE a
     * source's headers are not: those are worked out by pdeps while
     * the build runs, and nothing here ever sees them.
     *
     * "Nothing builds" is asked of every project in the run, since a
     * prerequisite built by the project above is still built.  And
     * the object directory is left out of this half, because it is
     * where files land that are output without any rule being named
     * after them: a vendored tree installs its headers into it, and a
     * source that includes one has a prerequisite in there that no
     * rule builds.  A hand-written file kept in an object directory
     * is still refused when a line names it, above. */
    auto built = std::set<std::string>();
    for (const auto& project: run)
        for (const auto& target: project->targets())
            built.insert(file_utils::normalize_path(target->name()));

    for (const auto& project: projects) {
        auto seen = std::set<makefile::target*>();

        std::function<void(const makefile::target::ptr&,
                           const debug_info::ptr&)> walk =
            [&](const makefile::target::ptr& target,
                const debug_info::ptr& line)
            {
                if (seen.insert(target.get()).second == false)
                    return;

                for (const auto& dep: target->deps()) {
                    if (dep->cmds().size() != 0 || dep->deps().size() != 0) {
                        walk(dep, line);
                        continue;
                    }

                    auto path = file_utils::normalize_path(dep->name());
                    if (built.find(path) != built.end())
                        continue;

                    auto taken = distclean_takes(path, dirs, true, resolved);
                    if (taken.found == false)
                        continue;

                    std::cerr << std::to_string(line) << "\n"
                              << "  error: " << taken.what << " inside '"
                              << taken.where << "', " << taken.role
                              << "\n"
                              << "  no line names it, but '"
                              << target->name() << "' is built from it:"
                              << " pconfigure found it by reading what"
                              << " this line builds, the way it follows"
                              << " an '#include', and that makes it as"
                              << " much a source as anything a SOURCES"
                              << " names\n";
                    explain_distclean_takes(taken);
                    abort();
                }
            };

        for (const auto& target: project->targets()) {
            /* A target no line asked for is a vendored tree's, and
             * what that reads is its own business. */
            auto line = project->written_by(target->name());
            if (line == NULL)
                continue;
            walk(target, line);
        }
    }
}

void project::check_autodeps(void) const
{
    /* Everything one AUTODEPS reached, gathered under the line that
     * wrote it rather than under any of the targets that inherited
     * it.  A line at the top of a target is read by every test
     * underneath, so asking the question per target would ask it
     * fifty times and answer it fifty times the same way.
     *
     * Only the contexts a language actually gets picked for: those
     * are the ones with an opinion about what AUTODEPS means, and
     * they're the only ones it is safe to ask, since asking anything
     * else is how you find out there was no language for it. */
    auto first = std::map<std::string, context::ptr>();
    auto order = std::vector<std::string>();
    auto links = std::map<std::string, bool>();

    std::function<void(const context::ptr&)> walk =
        [&](const context::ptr& ctx)
        {
            for (const auto& child: ctx->children)
                if (child->check_type({context_type::TEST}) == true)
                    walk(child);

            if (ctx->autodeps == true || ctx->autodeps_debug == NULL)
                return;

            auto where = std::to_string(ctx->autodeps_debug);
            if (first.find(where) == first.end()) {
                first[where] = ctx;
                order.push_back(where);
                links[where] = false;
            }

            if (pick_language(ctx->languages, ctx)->autodeps_links() == true)
                links[where] = true;
        };

    for (const auto& ctx: _processor->output_contexts())
        walk(ctx);

    for (const auto& where: order) {
        /* One target that links is enough to make the line worth
         * writing.  A line that covers a compiled binary and the
         * BASH tests underneath it was written for the binary, and
         * what it costs the tests is a different complaint than this
         * one -- this is about a line that bought nothing at all. */
        if (links[where] == true)
            continue;

        const auto& ctx = first[where];
        auto language = pick_language(ctx->languages, ctx);

        ctx->strictness.complain(
            strict_since::v0_13(),
            ctx->autodeps_debug,
            "'AUTODEPS = false' takes nothing out of a " + language->name()
            + " build: nothing under this line is linked, so all it does"
            " is stop what it reached being rebuilt when an include"
            " changes",
            "drop the line -- what it is for is keeping the sources"
            " behind a compiled target's headers from being linked into"
            " it, and there is no such target here");
    }
}

void project::check_test_scratch(void) const
{
    /* A test's scratch directory is the path of its compiled self
     * with ".scratch" on the end, beside every other test of the same
     * target -- which is where a consumer finds a predecessor's
     * fixture, by taking the dirname of its own and adding the other
     * test's name.  So a sibling called "t.scratch" is compiled to the
     * very path "t" is given as a directory, and a sibling called
     * "t.scratch/x" is compiled into the middle of it.  Neither can be
     * made to work: ptest's mkdir found a program where the directory
     * should be and "t" failed, or the program was copied into the
     * directory and ptest was asked to run that, and "make clean" of
     * "t" removed the other test's program along with its own scratch.
     *
     * Moving every scratch directory somewhere no test can be named
     * was the alternative, and it was not taken: where a test's
     * scratch is, relative to its siblings', is what the manual tells
     * a consumer to rely on, and a collision this rare is better
     * answered with a sentence than with a layout every suite that
     * shares a fixture has to be rewritten for.  Only the pair is
     * refused, not the suffix: a "t.scratch" with no "t" beside it
     * collides with nothing.
     *
     * The paths are the compiled tests' own, worked out the way the
     * languages that write their rules work them out, so that two
     * targets with one OBJDIR are compared where they actually land
     * and two with different ones are not.  It is the later of the
     * two lines that is refused whichever of them owns the scratch --
     * the only order a reader can predict without knowing which name
     * is which.  The output contexts come out in the order their
     * lines were written, and a target's tests in the order of theirs,
     * so a walk of them is that order. */
    struct claim {
        context::ptr ctx;
        bool scratch;
    };
    auto claimed = std::map<std::string, claim>();

    /* Whether a test lands at a scratch directory or somewhere below
     * it.  The other way round, a scratch directory inside a test, is
     * only possible when that test also has the scratch's owner inside
     * it, which is two tests nested in each other and not a question
     * about scratch at all. */
    auto within = [](const std::string& test, const std::string& scratch)
        {
            if (test.compare(0, scratch.size(), scratch) != 0)
                return false;
            return test.size() == scratch.size()
                || test[scratch.size()] == '/';
        };

    std::function<void(const context::ptr&)> walk =
        [&](const context::ptr& ctx)
        {
            if (ctx->check_type({context_type::TEST}) == true) {
                auto test = file_utils::normalize_path(
                    ctx->obj_dir + "/" + ctx->unbased(ctx->check_dir)
                    + "/" + ctx->cmd->data());
                auto mine = std::vector<std::pair<std::string, bool>>{
                    {test, false},
                    {test + ".scratch", true},
                };

                for (const auto& path: mine) {
                    for (const auto& pair: claimed) {
                        /* Two tests at one path, or two scratch
                         * directories, are not this collision: the
                         * first is one test written twice and the
                         * second follows from it.  Neither is a test's
                         * own path against its own scratch. */
                        if (pair.second.scratch == path.second)
                            continue;
                        if (pair.second.ctx == ctx)
                            continue;
                        const auto& test_path = path.second ? pair.first
                                                            : path.first;
                        const auto& scratch_path = path.second ? path.first
                                                               : pair.first;
                        if (within(test_path, scratch_path) == false)
                            continue;

                        /* Said from the refused line's side, since
                         * that is the line the reader is pointed at:
                         * either this test is where the other keeps
                         * its scratch, or this test's scratch is where
                         * the other one is. */
                        auto other = std::to_string(
                            pair.second.ctx->cmd->debug());
                        auto inside = (test_path != scratch_path);

                        std::cerr << std::to_string(ctx->cmd->debug())
                                  << "\n";
                        if (path.second == false)
                            std::cerr << "  error: this test is compiled to '"
                                      << path.first << "', which is "
                                      << (inside ? "inside " : "")
                                      << "the scratch directory '"
                                      << pair.first << "' of the test on "
                                      << other << "\n";
                        else
                            std::cerr << "  error: this test's scratch"
                                      << " directory is '" << path.first
                                      << "', and the test on " << other
                                      << " is compiled to '" << pair.first
                                      << "'" << (inside ? ", inside it" : "")
                                      << "\n";
                        std::cerr << "  every test keeps '<name>.scratch'"
                                  << " beside its own compiled self, so"
                                  << " rename one of the two tests so"
                                  << " that neither is the other's name"
                                  << " with '.scratch' on the end, or"
                                  << " inside a directory named that\n";
                        abort();
                    }
                }

                for (const auto& path: mine)
                    if (claimed.find(path.first) == claimed.end())
                        claimed[path.first] = claim{ctx, path.second};
            }

            for (const auto& child: ctx->children)
                walk(child);
        };

    for (const auto& ctx: _processor->output_contexts())
        walk(ctx);
}

void project::check_test_order(void) const
{
    /* A DEPTESTS resolves to the name of the target that runs the
     * test it waits for, since both of them are that test's check
     * directory and its own name -- so what it names is either in
     * here or is nothing at all. */
    auto tests = this->tests();

    auto waits_for = std::map<std::string, std::vector<std::string>>();

    for (const auto& pair: tests) {
        const auto& ctx = pair.second;
        const auto& named = ctx->dep_tests;
        const auto& based = ctx->based_dep_tests();

        for (size_t i = 0; i < based.size(); ++i) {
            if (tests.find(based[i]) != tests.end()) {
                waits_for[pair.first].push_back(based[i]);
                continue;
            }

            /* A name that isn't a test is worth stopping for, because
             * the shape of the mistake is almost always a DEPTESTS
             * reaching for a test of some other target: the Makefile
             * that comes out of it is one where "make check" stops
             * with "No rule to make target", which names a path in a
             * check directory and nothing at all about the Configfile
             * that asked for it. */
            std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                      << "  error: DEPTESTS waits for '" << named[i]
                      << "', which is no test of this target\n"
                      << "  it would be '" << based[i]
                      << "', and nothing under this target writes that\n"
                      << "  a DEPTESTS names a test that shares this check"
                      << " directory, spelled the way its own TESTS line"
                      << " spelled it\n";
            abort();
        }
    }

    /* Tests that wait in a circle never run, and make says so by
     * dropping one of the edges and carrying on -- so the build works
     * and the order it was asked for silently isn't the one it used.
     * That's the worst way for this to go wrong, since the whole
     * point of a DEPTESTS is that the order is load-bearing. */
    auto walking = std::map<std::string, bool>();
    auto walked = std::map<std::string, bool>();
    auto stack = std::vector<std::string>();

    std::function<void(const std::string&)> walk =
        [&](const std::string& name)
        {
            walking[name] = true;
            stack.push_back(name);

            auto found = waits_for.find(name);
            if (found != waits_for.end()) {
                for (const auto& dep: found->second) {
                    if (walked[dep] == true)
                        continue;

                    if (walking[dep] == false) {
                        walk(dep);
                        continue;
                    }

                    /* Everything from where this name first went on
                     * the stack is the circle; whatever came before it
                     * is just how the walk got here. */
                    auto cycle = std::vector<std::string>();
                    auto in = false;
                    for (const auto& step: stack) {
                        if (step == dep)
                            in = true;
                        if (in == true)
                            cycle.push_back(step);
                    }

                    std::cerr << std::to_string(tests[dep]->cmd->debug())
                              << "\n";

                    if (cycle.size() == 1) {
                        std::cerr << "  error: this test's DEPTESTS waits"
                                  << " for itself\n"
                                  << "  a test can't be its own"
                                  << " predecessor, so there's no order"
                                  << " here to run it in\n";
                        abort();
                    }

                    std::cerr << "  error: this test's DEPTESTS wait in a"
                              << " circle, so none of them could ever"
                              << " run\n";
                    for (size_t i = 0; i < cycle.size(); ++i)
                        std::cerr << "    " << cycle[i] << " waits for "
                                  << cycle[(i + 1) % cycle.size()] << "\n";
                    std::cerr << "  break the circle: one of these tests has"
                              << " to be the one that goes first\n";
                    abort();
                }
            }

            stack.pop_back();
            walking[name] = false;
            walked[name] = true;
        };

    for (const auto& pair: tests)
        if (walked[pair.first] == false)
            walk(pair.first);
}

void project::check_stale_makefile(void) const
{
    /* Only a project a parent pulled in, since the file this is about
     * is one a parent wrote.  The project make gets run in owns the
     * Makefile at the top of it and always has. */
    if (_base.size() == 0)
        return;

    const auto path = _base + "Makefile";

    auto file = fopen(path.c_str(), "r");
    if (file == NULL)
        return;

    auto lines = file_utils::readlines(file);
    fclose(file);

    /* Spelled through the same function that builds the name, so the
     * two can't drift apart: a project with no directory has nothing
     * to put on the end, which leaves the part every one of them
     * starts with. */
    const auto marker = prefix_variable("");
    const auto assign = std::string(" ?=");

    auto variable = std::string();
    for (const auto& read: lines) {
        auto line = read;
        while (line.size() > 0
               && isspace((unsigned char)line[line.size() - 1]) != 0)
            line.pop_back();

        if (line.compare(0, marker.size(), marker) != 0)
            continue;

        /* The one declared with nothing after it is the project's own,
         * and only a parent ever declares that: a Makefile written
         * from inside a project has no directory to be found through,
         * so it has no such line.  The lines that say where some
         * other project is have that project's directory on the end,
         * and those turn up in every Makefile pconfigure writes --
         * including the ones there is nothing wrong with. */
        if (line.size() <= marker.size() + assign.size())
            continue;
        if (line.compare(line.size() - assign.size(),
                         assign.size(), assign) != 0)
            continue;

        variable = line.substr(0, line.size() - assign.size());
        break;
    }

    if (variable.size() == 0)
        return;

    /* Said rather than acted on.  It is a generated file and this run
     * could perfectly well delete it, but a build system that quietly
     * removes a Makefile is a worse thing to be wrong about than a
     * stale file is, and there is no way from here to be sure nothing
     * outside this run was pointed at it. */
    std::cerr << "'" << path << "' was written by an older pconfigure,"
              << " and nothing includes it now\n"
              << "  the '" << variable << " ?=' at the top of it is what a"
              << " parent used to set to say where this project is; this run"
              << " wrote '" << makefile_path() << "' instead\n"
              << "  a \"make\" in '" << _base << "' would still find it and"
              << " build out of whatever the tree looked like back then\n"
              << "  delete it, or run pconfigure in '" << _base << "' to"
              << " replace it with one for building this project on its"
              << " own\n";
}

makefile::target::ptr project::cache_clean_target(const std::vector<ptr>& projects) const
{
    auto commands = std::vector<std::string>();
    for (const auto& project: projects) {
        /* This works by reading the Makefile back and keeping the
         * files it still knows how to build.  A project that a parent
         * can include writes its paths in terms of a variable, so
         * what's in the file isn't what's on disk and reading it back
         * would decide that nothing is still wanted -- which would
         * throw away the whole object cache rather than the stale
         * part of it.  So only a project whose Makefile says what it
         * means gets one of these. */
        if (project->_base.size() > 0)
            continue;

        auto obj_dirs = std::map<std::string, bool>();
        for (const auto& context: project->_processor->output_contexts())
            obj_dirs[context->obj_dir] = true;
        for (const auto& vendored: project->_processor->vendored())
            obj_dirs[vendored->ctx()->obj_dir] = true;

        /* A vendored tree builds into here too, and what it puts in
         * its output directory is between it and its own build
         * system: the Makefile says nothing about any of it, so
         * reading the Makefile back would decide the whole thing was
         * stale and throw away a build that's perfectly good.
         *
         * And what such a tree installs, which is the same problem
         * one directory away: an install prefix holds a bin, a lib
         * and an include tree that no rule in the Makefile names --
         * only the files a SUBPROJECT_TARGETS named outright get
         * rules -- so reading the Makefile back would delete all of
         * it and leave the build stamp saying the tree is installed.
         * Nothing later puts any of it back, and the first thing to
         * fail is a compile against a header that was there
         * yesterday.  See build_system::install_dir(), which is also
         * where the reason distclean has nothing to say about a
         * prefix is written down.
         *
         * The trees asked are this project's own, and that is enough
         * because a prefix is a directory inside the object directory
         * of the project that vendored the tree: a tree some other
         * project vendored installs into that project's object
         * directory, which is not one of the directories being walked
         * here. */
        auto spared = std::vector<std::string>();
        auto prune = std::string();
        auto spare = [&](const std::string& dir) {
            if (dir.size() == 0)
                return;

            /* Once each, and not at all for a directory already
             * inside one that is being spared.  Both of those come up
             * in the ordinary case rather than in a corner: a default
             * prefix sits inside its own tree's output directory, and
             * several trees sharing one --prefix name one directory
             * between them.  Saying either again would only make a
             * command that is already long enough to be unreadable
             * longer. */
            for (const auto& already: spared)
                if (file_utils::inside(dir, already) == true)
                    return;

            spared.push_back(dir);

            /* Quoted rather than wrapped in a pair of apostrophes
             * written out here, because this is the one path in this
             * command a Configfile author writes by hand: everything
             * else pruned below is a name pconfigure made up.  An
             * install prefix with an apostrophe in it ends the
             * quoting a hand-written pair would have opened and hands
             * the rest of the line to the shell, so "make
             * cache-clean" stops with "unexpected EOF while looking
             * for matching" from a command whose entire job was to
             * leave that directory alone.
             *
             * The '*' goes inside the quotes with the directory, the
             * way it already did: it is find's glob rather than the
             * shell's, and a shell that expanded it would hand find
             * whatever happened to be in there today. */
            prune += " -not -path " + string_utils::quoted(dir + "/*");
        };

        for (const auto& vendored: project->_processor->vendored()) {
            spare(vendored->output_dir());
            spare(vendored->install_dir());
        }

        /* pconfigure wrote this one, and nothing the Makefile builds
         * is made from it: reading the Makefile back would decide it
         * was stale and throw away the record of where the test
         * results live, which only a configure or a make from the top
         * of the tree would put back. */
        prune += " -not -path '"
              + project->_processor->root_context()->obj_dir
              + "/check-dirs'";
        prune += " -not -path '"
              + project->_processor->root_context()->obj_dir
              + "/check-stamp'";

        /* And the Makefiles a configure from above left in here, for
         * the same reason and with more at stake.  Only a build run
         * inside a subproject ever reaches one of these, and the
         * Makefile being read back is that build's own -- which has
         * never heard of the parent and would call the parent's copy
         * stale.  Deleting it breaks a build somewhere else entirely,
         * which is the kind of damage nobody thinks to go looking
         * for. */
        prune += " -not -path '"
              + project->_processor->root_context()->obj_dir
              + "/Makefile.*'";

        /* And these, for the same reason: a project that works its
         * dependencies out during the build keeps what pdeps needs to
         * know in here, and the Makefile names those as
         * prerequisites.  Throwing one away no longer stops the
         * build, since the Makefile can write it back, but it comes
         * back newer than every fragment that read it -- so a cache
         * clean would cost every dependency in the project being
         * worked out again. */
        if (project->_processor->autoreconfigure() == true)
            prune += " -not -name 'deps-context-*'";

        /* And the file that hashes what goes into each link, which
         * the link rules name as a prerequisite.  It is pconfigure's
         * output, written at configure time and refreshed by the
         * reconfigure, which is the same reason the Makefiles above
         * are spared; the one difference is that it exists for every
         * project rather than only for an AUTORECONFIGURE one, so
         * this is said without a condition.  The Makefile can write
         * one back, so throwing it away no longer stops the build,
         * but what comes back is newer than the link: a cache clean
         * would cost a relink of everything. */
        prune += " -not -name 'link-inputs'";

        /* And the scratch a test was given, which the Makefile names
         * as an argument to ptest rather than as something it knows
         * how to build -- so reading it back decides every byte in
         * there is stale.  What is in there is exactly what somebody
         * did not want copied around: a fixture too big to collect
         * into a result, and usually too expensive to make twice.
         * Throwing it away here would be a cache-clean that costs
         * more than the cache it reclaimed.  "make clean" is what
         * removes these, along with the test they belong to. */
        prune += " -not -path '*.scratch/*'";

        for (const auto& pair: obj_dirs) {
            const auto& dir = pair.first;

            /* '|' rather than '/' as the delimiter, since a directory
             * that has one in it would otherwise end the command. */
            /* What the build still knows how to make.  For a
             * project that works its dependencies out during the
             * build, most of that is not in the Makefile at all: the
             * objects and the fragments below the ones pconfigure
             * named are written down by pdeps, in the fragments
             * themselves.  Reading only the Makefile would decide the
             * whole object cache was stale and throw away a build
             * that is perfectly good.
             *
             * The fragments are read with "-exec cat {} +" rather than
             * handed over as arguments, since a large project has one
             * per source and a command line has a limit. */
            auto wanted =
                "sed -n 's|\\(^" + dir + "/[^[:space:]:]*\\):.*|\\1|p' "
                + project->makefile_path();
            if (project->_processor->autoreconfigure() == true)
                wanted += "; find " + dir + " -name '*.d' -exec cat {} + "
                          "| sed -n 's|\\(^" + dir
                          + "/[^[:space:]:]*\\):.*|\\1|p'";

            /* And the record each GENERATE keeps of the recipe that
             * wrote its dependency fragment.  It is written at
             * configure time with no rule behind it, so the Makefile
             * never names it, and the next configure reads a missing
             * record the same way it reads a mismatched one: as a
             * fragment some other recipe wrote.  That fragment is
             * thrown away and the script's "--deps" runs again, so
             * losing these would cost every GENERATE in the project
             * being asked its dependencies over -- and those scripts
             * are somebody else's code, which is not something to be
             * running for nothing.
             *
             * Only the GENERATEs configured now, though, and that is
             * why these are named one at a time rather than spared by
             * a "*.d-context" pattern.  A pattern spares the record of
             * a GENERATE that has since been deleted from the
             * Configfile too: its output and its fragment go, and the
             * record is left on its own in the object directory for
             * ever, with nothing left that will read it.  The paths
             * are spelled the way the fragment's rule spells its
             * target, which is how find spells them as well, and they
             * are compared as strings rather than handed to find as
             * patterns, so an output with a '[' or a '*' in its name
             * means what it says. */
            for (const auto& context: project->_processor->output_contexts()) {
                if (context->check_type({context_type::GENERATE}) == false)
                    continue;

                auto record = language_gen_proc::fragment_recipe_record(
                    context->gen_dir + "/" + context->cmd->data());
                if (record.compare(0, dir.size() + 1, dir + "/") != 0)
                    continue;

                wanted += "; printf '%s\\n' "
                          + string_utils::quoted(record);
            }

            commands.push_back(
                "comm -23 "
                "<(find " + dir + " -type f" + prune + " | sort) "
                "<({ " + wanted + "; } | sort -u) "
                "| xargs -r rm -f"
            );
            commands.push_back(
                "find " + dir + " -type d -empty" + prune + " -delete");
        }
    }

    return std::make_shared<makefile::target>(
        "cache-clean",
        "CACHE-CLEAN",
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        commands,
        std::vector<std::string>{"cache-clean"}
    );
}

std::map<std::string, std::string>
project::distclean_dirs(const std::vector<ptr>& projects)
{
    /* The first thing a directory is called for wins, which only
     * matters for a LIBDIR moved onto some other output directory:
     * either name is true, and it is removed once either way. */
    auto dirs = std::map<std::string, std::string>();
    auto add = [&](const std::string& dir, const std::string& what) {
        dirs.emplace(dir, what);
    };

    for (const auto& project: projects) {
        /* Every project has an object directory whether or not it
         * builds anything, because pconfigure writes to it: the list
         * of where test results land goes there.  A project that only
         * pulls in other projects has no context to find that
         * directory through, so it gets named outright. */
        add(project->_processor->root_context()->obj_dir,
            "the object directory");

        /* A vendored tree builds into this project's object
         * directory, so it's already covered by whatever covers that
         * -- but a project that vendors something and builds nothing
         * of its own has no contexts to find it through.
         *
         * What it installed is covered too, and deliberately without
         * being named: an install prefix is a directory inside the
         * object directory of the project that vendored the tree, so
         * removing the object directory removes it.  Naming it here
         * instead would mean writing a path out of a Configfile into
         * an "rm -rf", which is a thing to be very sure about and
         * something this does not have to be sure about at all.  See
         * build_system::install_dir(). */
        for (const auto& vendored: project->_processor->vendored())
            add(vendored->ctx()->obj_dir, "the object directory");

        /* Only the contexts something is built in, so a project that
         * builds nothing of its own has no "bin" or "lib" here: there
         * is nothing of its in either for distclean to take. */
        for (const auto& context: project->_processor->output_contexts()) {
            /* A HEADERS builds into the include directory, but the
             * include directory isn't output: a HEADERS with nothing
             * under it installs a header straight out of there, one
             * somebody wrote and nothing in the build can write
             * again.  So it's left off, and what a HEADERS does copy
             * in there is taken back by name instead -- see
             * distclean_files(). */
            if (context->type != context_type::HEADER)
                add(context->bin_dir, "where binaries go");
            add(context->check_dir, "where test results go");
            add(context->lib_dir, "where libraries go");
            add(context->obj_dir, "the object directory");
        }
    }

    return dirs;
}

std::map<std::string, std::string>
project::distclean_files(const std::vector<ptr>& projects)
{
    auto files = std::map<std::string, std::string>();

    for (const auto& project: projects) {
        for (const auto& context: project->_processor->output_contexts()) {
            if (context->type != context_type::HEADER)
                continue;

            /* One with nothing under it is the hand-written header
             * itself, read where it is and never copied anywhere but
             * the install prefix.  One with a SOURCES under it is a
             * copy, and lands exactly where languages/bash.c++ puts
             * every BASH-like target. */
            if (context->children.size() == 0)
                continue;

            files.emplace(context->bin_dir + "/" + context->cmd->data(),
                          context->bin_dir);
        }
    }

    return files;
}

makefile::target::ptr project::distclean_target(const std::vector<ptr>& projects) const
{
    auto dirs = distclean_dirs(projects);
    auto files = distclean_files(projects);
    auto makefiles = std::vector<std::string>();
    for (const auto& project: projects)
        makefiles.push_back(project->makefile_path());

    /* Every one of these is quoted, and none of them is a path a
     * Configfile author wrote by hand in the sense an install prefix
     * is: they are output directories, which is to say a name
     * pconfigure made up or a name a LIBDIR or a SUBPROJECTS handed
     * it -- the only two commands in this pconfigure that move one.
     * That second half is the half that wants this.  A "LIBDIR = my
     * dir" reaches here as an "rm -rf my dir", which is two
     * directories rather than one and neither of them the one that
     * was meant; a SUBPROJECTS whose directory has an apostrophe in
     * it reaches here as a line the shell gives up on before running
     * any of it, so "make distclean" stops partway through with a
     * syntax error.
     *
     * Quoting is the whole of what this does about them.  Whether
     * either one may name the directory it names at all is settled
     * where the line was read, in command_processor::process_one():
     * a LIBDIR and a SUBPROJECTS that leave the project are refused
     * there, and a subproject one of these directories would take
     * with it is refused once the whole run has been read, in
     * check_distclean_spares_subprojects().  So by the time a path
     * arrives at this "rm -rf" the only thing left to get wrong about
     * it is how many words of shell it is. */
    auto commands = std::vector<std::string>();
    for (const auto& pair: dirs)
        commands.push_back("rm -rf " + string_utils::quoted(pair.first));
    for (const auto& path: makefiles)
        commands.push_back("rm -rf " + string_utils::quoted(path));

    /* The header copies go one name at a time, and then so do the
     * directories the copies needed -- "HEADERSRC += lib/x.h" makes
     * "include/lib" as well as the file -- deepest first, up to and
     * including the include directory itself.  Each of those is an
     * "rmdir", which only ever removes a directory that's empty: one
     * that still holds a hand-written header is left exactly as it
     * was, and one that held nothing but copies was the build's to
     * begin with.  It fails, harmlessly and on purpose, for each
     * directory that isn't empty or was never made, which is why it
     * is told to be quiet about it. */
    auto made = std::set<std::string>();
    for (const auto& pair: files) {
        commands.push_back("rm -f " + string_utils::quoted(pair.first));

        auto dir = pair.first;
        while (dir.size() > pair.second.size()) {
            dir = dir.substr(0, dir.find_last_of('/'));
            made.insert(dir);
        }
    }

    auto deepest_first = std::vector<std::string>(made.begin(), made.end());
    std::stable_sort(deepest_first.begin(), deepest_first.end(),
                     [](const std::string& a, const std::string& b) {
                         return a.size() > b.size();
                     });
    for (const auto& dir: deepest_first)
        commands.push_back("rmdir " + string_utils::quoted(dir)
                           + " 2>/dev/null || true");

    /* "distclean" is a name, like every other goal the Makefile
     * answers to, and has to be said to be one.  Otherwise a file
     * called "distclean" at the top of the tree -- notes, a script,
     * the output of an earlier "make distclean > distclean" -- is an
     * up-to-date target with no prerequisites, and make answers
     * "'distclean' is up to date" and removes nothing at all, with an
     * exit status of 0 to say it went fine.  The other global goals
     * get their .PHONY lines in makefile::write_to_file(); this one
     * carries its own because it is a rule built here rather than a
     * goal every Makefile has. */
    return std::make_shared<makefile::target>(
        "distclean",
        "DISTCLEAN",
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        commands,
        std::vector<std::string>{"distclean"}
    )->as_phony();
}

/* The options this run was given, spelled as the right-hand side of a
 * make assignment whose value a recipe then hands to a shell.  Two
 * languages read it on the way, so each word is quoted for both: the
 * shell's quoting and make's '$' come from echoed(), since what is
 * being kept is what was typed and not what a variable holds by the
 * time make gets to it, and the '#' that would end the assignment as
 * a comment is escaped here.  make reads a run of backslashes in
 * front of a '#' as escapes of each other, so those are doubled
 * first to come out the other side as they went in.
 *
 * A word with nothing in it that either language would read is left
 * as it is, which is nearly every word anybody types and keeps the
 * line legible to somebody reading the Makefile to find out how the
 * tree was configured. */
static std::string rerun_args(void)
{
    auto out = std::string();
    for (const auto& arg: command_line_read()) {
        /* A make assignment is one line, and no escaping makes a
         * newline part of one.  Refused rather than dropped, because
         * a reconfigure with the word missing or split is a
         * different configure from the one that was asked for, and
         * nothing would say so. */
        if (arg.find('\n') != std::string::npos) {
            std::cerr << "Command-line option '" << arg
                      << "' has a newline in it\n"
                      << "  the Makefile records how pconfigure was run,"
                      << " so that the build can run it the same way"
                      << " again, and a make variable cannot hold a"
                      << " newline\n"
                      << "  give the option without the newline\n";
            abort();
        }

        auto plain = arg.size() > 0;
        for (const auto& c: arg)
            if (isalnum(c) == 0 && strchr("-_./=+,:@%", c) == NULL)
                plain = false;

        auto spelled = plain ? arg : string_utils::echoed(arg);

        auto escaped = std::string();
        auto backslashes = std::string();
        for (const auto& c: spelled) {
            if (c == '\\') {
                backslashes += c;
                continue;
            }
            if (c == '#')
                escaped += backslashes + backslashes + "\\#";
            else
                escaped += backslashes + c;
            backslashes.clear();
        }
        escaped += backslashes;

        out += (out.size() > 0 ? " " : "") + escaped;
    }
    return out;
}

void project::write_makefile(const std::vector<makefile::implied_dep>& implied,
                             const std::vector<ptr>& aggregated,
                             const std::vector<ptr>& everyone) const
{
    /* FIXME: If any target is verbose, then all are. */
    auto verbose = [&](void) -> bool {
        for (const auto& context: _processor->output_contexts())
            if (context->verbose == true)
                return true;
        return false;
        }();

    /* Every project in the run other than the ones this Makefile
     * includes itself.  A path inside one of those is a path this
     * project can perfectly well name -- a header a sibling owns, say
     * -- and one it has no idea how to build, so it gets named
     * through that project's variable and nothing else. */
    auto children = std::set<std::string>();
    for (const auto& child: _children)
        children.insert(child->base());

    auto peers = std::vector<std::pair<std::string, std::string>>();
    for (const auto& other: everyone) {
        if (other->_base == _base)
            continue;
        if (children.find(other->_base) != children.end())
            continue;

        /* The project at the top of the run has no directory of its
         * own, so there's nothing in a path that says it belongs
         * there and no variable that could be put in front of it.
         * Nothing names one of its paths from below anyway: a
         * project only ever gets to name things inside itself. */
        if (other->_base.size() == 0)
            continue;

        peers.push_back(std::make_pair(other->_base,
                                       prefix_variable(other->_base)));
    }

    auto prefix = _base.size() == 0
        ? makefile::path_prefix()
        : makefile::path_prefix(_base, prefix_variable(_base), peers);

    auto out = std::make_shared<makefile::makefile>(
        verbose,
        _processor->root_context()->obj_dir,
        prefix);

    /* Where each of those projects is, said the way it looks from
     * here.  Whoever make was actually run in says it first and so
     * says it for everybody. */
    for (const auto& peer: peers)
        out->add_peer(peer.second,
                      file_utils::relative_directory(_base, peer.first));

    for (const auto& child: _children)
        out->add_subproject(prefix_variable(child->base()), child->base(),
                            child->makefile_include());

    for (const auto& target: _targets)
        out->add_target(target);

    for (const auto& dep: implied)
        out->add_dep(dep.target, dep.dep);

    /* A project's "make check" stamp waits on its children's, so that
     * asking any one project to run its tests runs the tests of
     * everything it pulled in too. */
    for (const auto& child: _children)
        out->add_check_stamp(
            child->processor()->root_context()->obj_dir + "/check-all-done");

    /* Running make here means collecting the test results of, and
     * knowing the build directories of, this project and everything
     * it pulled in.  These only get written out for a standalone
     * build, so a parent's copies are what run when there is one. */
    for (const auto& project: aggregated)
        if (project->has_check_dir())
            out->add_check_dir(
                project->processor()->root_context()->check_dir,
                project->processor()->abrt_is_fail());

    /* Same reason, and the same list: a suite is a name make can be
     * asked for, so the Makefile that gets asked is the one that has
     * to know about every test in it.  Two projects that both declare
     * a suite of one name have one suite here, since there is one
     * rule with that name to run -- which is also why the asking is
     * done of the whole list at once rather than of each project in
     * turn: a suite that includes another includes all of it. */
    for (const auto& suite: aggregate_test_suite_members(aggregated))
        out->add_test_suite(suite.first, suite.second);

    /* And every test there is, which is the set "make check" runs when
     * no suite was asked for, so that its report is about that set
     * rather than about whatever results happen to be on disk. */
    for (const auto& project: aggregated)
        for (const auto& test: project->tests())
            out->add_check_result(test.first);

    /* Which of them "make check" means, which is this project's
     * answer rather than the aggregate: the rule belongs to whoever
     * make was run in, and a subproject that has an opinion about its
     * own "make check" doesn't get to have one about a parent's. */
    out->set_default_test_suite(_processor->default_test_suite());

    /* A project that bootstraps its own pconfigure has the rule that
     * runs it in the Makefile it keeps beside this one, since that is
     * where the pconfigure to run is named.  Two of them would be two
     * recipes for the one name. */
    if (_processor->bootstrap().size() > 0)
        out->skip_reconfigure();

    /* The project pconfigure was run in is the one that was given the
     * options, and so the one that remembers them.  A subproject's
     * Makefile keeps the empty default it always had: the options
     * that configured the tree above it are relative to the tree
     * above it -- a --srcpath, a --config naming one of its
     * Configfiles -- and mean something else from inside. */
    if (_base.size() == 0)
        out->rerun_with(rerun_args());

    /* Under AUTORECONFIGURE the build is what keeps itself current,
     * and a Configfile is the one input to it that nothing was
     * watching.  Everywhere else the promise is deliberately the
     * other way round: a Makefile says what the Configfiles said the
     * last time somebody ran pconfigure, and running it again is
     * something a person asks for.
     *
     * Only the project make was run in gets the rule, and it gets
     * everybody's names -- the list is one list for the whole run.
     * That is the right shape rather than a convenient one: a
     * subproject cannot be configured from inside itself, so a
     * subproject's Configfile changing has to re-run the pconfigure
     * up here, and prerequisites written down there would be
     * prerequisites of a file make has no rule for.
     *
     * What this does not promise: a Configfile that is a program is
     * on its own for whatever it reads unless it says otherwise with
     * a CONFIG_DEPS, a Configfile that is deleted is not noticed --
     * the $(wildcard) that keeps a missing one from stopping the
     * build is the same thing that keeps its going away quiet -- and
     * a target that stopped being asked for keeps whatever it last
     * built.
     *
     * Whether the rule is written is a question about every project
     * in the run, not only this one, for the same reason the rule
     * lives up here.  A subproject that says AUTORECONFIGURE under a
     * top that doesn't has its own setting win -- it gets pdeps for
     * its sources -- but asking only this project left it with no
     * reaction to an edit of its own Configfile and with a deleted
     * object directory stopping every make, since both of those can
     * only be answered from here.  So one project asking is enough,
     * and it watches the whole list rather than that project's share
     * of it: what a subproject builds is written out of the Configfile
     * above it as well, which is where its SUBPROJECTS line and
     * everything it inherits live, and that is the shape the opposite
     * split (a top that asks, a subproject that says false) already
     * has. */
    auto anyone_asked = [&](void) -> bool {
        for (const auto& other: everyone)
            if (other->_processor->autoreconfigure() == true)
                return true;
        return false;
        }();

    /* Which of the names below a vendored tree in this run installs,
     * so the Makefile can have make build it before deciding whether
     * to reconfigure (see makefile::write_to_file()).  Only a vendored
     * tree's outputs, and that is the whole of the restriction rather
     * than a first cut at it: their rules read nothing but the tree's
     * own sources and options, so they can be built while make is
     * still remaking the makefiles it includes.  Anything pconfigure
     * links is the other way round -- its object list comes out of
     * pdeps fragments make has not read yet at that point, which is
     * the fresh-checkout failure described below for the bootstrapped
     * tool -- so a CONFIG_DEPS on one of those keeps waiting for the
     * file to turn up on its own. */
    auto vendored_outputs = [&](const std::vector<std::string>& paths) {
        auto built = std::vector<std::string>();
        for (const auto& path: paths) {
            auto found = false;
            for (const auto& other: everyone)
                for (const auto& tree: other->_processor->vendored())
                    if (tree->vendored() && tree->produces(path))
                        found = true;
            if (found)
                built.push_back(path);
        }
        return built;
    };

    /* Without AUTORECONFIGURE a Makefile is not rewritten because a
     * Configfile changed, which is the promise above, and none of the
     * Configfiles are named.  A CONFIG_DEPS line is a different thing
     * from a Configfile, though: it is the project saying in so many
     * words that its Makefile is written out of this path, and the
     * manual says a project with a committed Makefile beside the
     * generated one gets the prerequisite either way, for the
     * committed recipe to act on.  It did not -- the names went onto
     * the one list only AUTORECONFIGURE writes out -- so a project
     * that bootstraps its pconfigure, whose committed Makefile already
     * has the recipe that writes this one, never reconfigured when the
     * directory a CONFIG enumerates gained a file, and went on
     * building the tree as it was.
     *
     * So in a project with a BOOTSTRAP the names are written as
     * prerequisites with no recipe, the other half of the rule in the
     * committed Makefile.  A vendored tree's output is written bare
     * there, as under AUTORECONFIGURE and for the same reason: the
     * first make of a fresh tree builds the tool and configures
     * against it, rather than against its absence.
     *
     * A project with no committed Makefile gets nothing, though.
     * There the prerequisite could never lead to a reconfigure, and
     * it is not inert: make remakes the makefiles it includes before
     * it looks at any goal, "make clean" and "make -n" included, and
     * that remakes every prerequisite with a rule.  So a CONFIG_DEPS
     * on something this build makes -- a vendored tree's tool, or a
     * binary pconfigure links -- would have a clean or a dry run
     * rebuild it whenever a source of it changed, even through the
     * $(wildcard) once the file exists, and gain nothing from it. */
    if (_base.size() == 0 && anyone_asked == false
        && _processor->bootstrap().size() > 0
        && config_deps_named().size() > 0) {
        out->written_out_of(config_deps_named(),
                            vendored_outputs(config_deps_named()));
    }

    if (_base.size() == 0 && anyone_asked == true) {
        out->reconfigure_on(configfiles_read(),
                            vendored_outputs(configfiles_read()));

        /* A project that bootstraps its own pconfigure builds the tool
         * that wrote this Makefile out of the Makefile itself: after
         * the first bootstrap the vendored tree is an ordinary
         * subproject, and the pconfigure in it is one more binary in
         * the same dependency graph as everything else.  Which makes
         * the binary an input to the configure step that nothing was
         * watching -- a source edited, the binary relinked, and this
         * Makefile still saying what the old binary said, for as long
         * as nothing else happened to run pconfigure.  So a tree that
         * bootstraps puts the tool on the same rule the Configfiles
         * are on, and the first make after the build relinked it
         * reruns it.
         *
         * The next make, not the same one, and that is the spelling
         * below rather than a thing anybody chose.  The tool is named
         * by its absolute path, which is a prerequisite make has no
         * rule for -- a timestamp and nothing more, exactly as the
         * fragments name pdeps (see deps_source() in cxx.c++, which
         * says why at length).  Named by the relative path the
         * vendored tree's own rule uses, make would find that rule
         * while it is remaking the makefiles it includes, and build
         * the tool then: before it has read the pdeps fragments that
         * say which objects the tool and its libraries are linked
         * out of.  On a fresh checkout none of those fragments exist
         * yet, so every library came out of an empty object list,
         * pdeps -- linked against them -- could no longer load, and
         * nothing could write the fragments that would have fixed
         * it.  The very first make of every tree that bootstraps a
         * real pconfigure stopped there, and so did every make after
         * it.  The relative spelling looked like it was only being
         * eager; it was linking out of a dependency graph make had
         * not finished reading.
         *
         * Through "$(wildcard)" for the reason pdeps is: "make clean"
         * deletes the tool along with everything else the build made,
         * and a bare path to a missing file is "No rule to make
         * target" on a tree that only needs building.
         *
         * Nothing here sets a loop going.  Every configure rewrites
         * this file unconditionally -- the comment at the top of
         * makefile::write_to_file() is the reason that is right and
         * not an oversight -- so the file comes back newer than the
         * tool that wrote it, and the next make has nothing left to
         * do.  It is the same settle the Configfile prerequisites
         * above already ride on, arrived at from the other side: those
         * name an input that changed on disk, this one an input the
         * build changed itself.
         *
         * The prerequisite is spelled here rather than in the
         * committed Makefile the recipe lives in, because of when the
         * two files are known: on a fresh checkout make has to remake
         * this Makefile before it has read it, and all it knows then
         * is what the committed one says -- where the binary does not
         * exist yet and no rule for it has been included, so naming it
         * there would stop the very first make with "No rule to make
         * target" before the bootstrap that builds it could run.  This
         * file is only read once a binary is in place, by which point
         * the subproject that builds it is included too.
         *
         * The path is this checkout's, which is wherever somebody
         * cloned it, so it is spelled for the rule line the same way
         * a CONFIG_DEPS is.  A checkout called "proj:v2" is no reason
         * to refuse a Configfile that never said so, and this rule is
         * on every make of the tree: a ':' in it stopped them all.
         *
         * Absolute by way of this directory rather than realpath() of
         * the binary, because the binary need not exist at configure
         * time -- a pconfigure run from somewhere else can configure
         * a tree whose own has not been built yet -- and the question
         * is about where this tree's tool will be, not where the one
         * running happens to live. */
        const auto& bootstrap = _processor->bootstrap();
        if (bootstrap.size() > 0) {
            char *here = ::realpath(".", NULL);
            if (here == NULL) {
                perror("realpath(\".\")");
                abort();
            }
            auto tool = std::string(here) + "/" + bootstrap
                      + "bin/pconfigure";
            free(here);
            out->add_dep(makefile_path(),
                         makefile::present_prerequisite(tool));
        }

        /* The other Makefiles this one includes, which a configure
         * writes and nothing else does.  Each lives in its project's
         * object directory, and an object directory is a thing people
         * delete -- by hand, or by running a vendored tree's own
         * bootstrap.sh, which starts from an empty one -- and until
         * now a deleted one was "No rule to make target" on every
         * make after, in a tree whose Configfiles had not changed and
         * whose answer was one configure away.  So each gets a rule
         * that is that configure.
         *
         * No prerequisites, so the rule means "if it is missing" and
         * nothing else: a file with no prerequisites and a rule is up
         * to date for as long as it exists, which is every make but
         * the one after it went away.  A configure writes every one
         * of them, so the make that remakes one comes back with all
         * of them and settles.  That is what keeps it from being the
         * empty-rule loop the Configfile prerequisites go through
         * $(wildcard) to avoid -- this rule makes the file it names.
         *
         * Order-only on this Makefile, because the two can be due on
         * the same make -- a Configfile edited and an object
         * directory deleted -- and two configures of one tree running
         * side by side under -j is two writers of every file in it.
         * Waiting on this one means a configure that was going to
         * happen anyway happens first, and the second one finds
         * everything already written.
         *
         * Every project the run includes, not only this one's
         * children, because a grandchild's Makefile is included from
         * its parent's and is as deletable as any other.  Named the
         * way the include names it, so that the rule is for the file
         * make goes looking for. */
        auto reconfigure = makefile::tool_command("pconfigure")
                         + " $(PCONFIGURE_ARGS)";
        for (const auto& other: aggregated) {
            if (other->_base == _base)
                continue;

            auto included = other->makefile_include();
            out->add_standalone_target(std::make_shared<makefile::target>(
                included,
                "PCONFIGURE",
                std::vector<makefile::target::ptr>{},
                std::vector<makefile::global_targets>{},
                std::vector<std::string>{reconfigure},
                std::vector<std::string>{}));
            out->add_dep(included, "| " + makefile_path());
        }
    }

    /* A tree that bootstraps its own pconfigure has "make clean" take
     * this Makefile with it, because the clean takes the tool.  The
     * vendored tree's binaries are build outputs like any other, so
     * cleaning deletes pconfigure and the tools beside it, the
     * libraries they load, and whatever headers the vendored build
     * generates for itself -- and none of that is something the
     * Makefile left behind can be trusted to build back.  Measured,
     * both ways: under AUTORECONFIGURE the next make went straight to
     * rewriting the pdeps fragments with a pdeps that was no longer
     * there ("No such file or directory"), and how to link pdeps is
     * what those fragments say; without it, the header the vendored
     * library includes could not be made again, since the clean took
     * phc, which makes it, along with the header.  Either way, every
     * make after a clean, until somebody reconfigured by hand.
     *
     * The committed Makefile already knows what to do about a missing
     * tool -- bootstrap it from source, which needs none of this --
     * but only gets asked when this file has to be written.  Removing
     * it is how it gets asked: a missing include is remade before
     * anything else is read, so the bootstrap and the configure finish
     * before any rule in here is even known, which is also what keeps
     * it from racing those rules under -j.  The cost is a bootstrap and
     * a configure after every clean, which is what the comment on that
     * rule always said a clean would cost. */
    if (_base.size() == 0 && _processor->bootstrap().size() > 0) {
        auto clean_name = "__pconfigure__clean-" + makefile_path();
        out->add_standalone_target(std::make_shared<makefile::target>(
            clean_name,
            "",
            std::vector<makefile::target::ptr>{},
            std::vector<makefile::global_targets>{},
            std::vector<std::string>{"rm -f " + makefile_path()},
            std::vector<std::string>{}));
        out->add_dep(".PHONY", clean_name);
        out->add_dep("clean", clean_name);
    }

    /* "make clean" also takes the whole of every check directory, and
     * not just the results each test's own clean rule names.  Those
     * rules are written from the tests the Configfiles name today, so
     * the result of a test somebody has since taken out was never
     * named by any of them and outlived every clean -- which is the
     * one result in there that nothing will ever make current again.
     * Every byte under a check directory is a result "make check"
     * left, or the directories it made to hold them: distclean already
     * removes them whole, and a source file in one is refused at
     * configure time (see check_distclean_spares_sources()), so there
     * is nothing in them for this to spare.  One rule for every
     * project this Makefile runs the tests of, the same list its
     * reports cover.
     *
     * It is spelled "rm -fr", as every other line a clean runs is,
     * rather than distclean's "rm -rf".  The two do the same thing,
     * but "make -n clean" is how somebody checks that a clean only
     * removes things, and the honest way to read that output is to
     * take out the removals and look at what is left -- which is
     * one pattern only while every removal is written the same way. */
    {
        auto commands = std::vector<std::string>();
        for (const auto& project: aggregated)
            commands.push_back(
                "rm -fr " + string_utils::quoted(
                    project->processor()->root_context()->check_dir));

        auto sweep_name = std::string("__pconfigure__clean-check-dirs");
        out->add_standalone_target(std::make_shared<makefile::target>(
            sweep_name,
            "",
            std::vector<makefile::target::ptr>{},
            std::vector<makefile::global_targets>{},
            commands,
            std::vector<std::string>{}));
        out->add_dep(".PHONY", sweep_name);
        out->add_dep("clean", sweep_name);
    }

    /* Every file the run wrote for a build to read and nothing in the
     * build makes, with a rule each that writes it again -- see
     * makefile::write_to_file() for why.  Only in the Makefile of the
     * project pconfigure ran in, and with every project's files: the
     * paths are spelled from up here, and a subproject's Makefile is
     * included from here, so the rules reach its files too.  A
     * subproject's Makefile carrying them as well would be two rules
     * for one file once included. */
    if (_base.size() == 0)
        out->restore_configure_outputs(file_utils::configure_outputs());

    /* The files a bare "ptest" reads are among those, but unlike a
     * link's inputs nothing in the build names them -- ptest reads
     * them, make never does -- so a rule to write them again is a rule
     * nothing asks for.  Hanging them off "all" and "check" is what
     * asks: the make that rebuilds a deleted object directory, or the
     * "make check" that refills it with results, puts them back as
     * well, and ptest reports on the same projects, scored the same
     * way and against the same stamp, as "make report" does.  Without
     * them it quietly falls back to this project's results alone.
     *
     * Every project's, not only this one's, because a subproject is a
     * directory somebody can walk into and run ptest in too.  Only
     * from up here, since only this Makefile has the rules: a
     * subproject's Makefile naming them would be "No rule to make
     * target" the first time somebody ran make in it with them gone. */
    if (_base.size() == 0) {
        for (const auto& project: aggregated) {
            const auto& obj_dir =
                project->_processor->root_context()->obj_dir;
            for (const auto& record: {obj_dir + "/check-dirs",
                                      obj_dir + "/check-stamp"}) {
                out->add_dep("all", record);
                out->add_dep("check", record);
            }
        }
    }

    out->add_standalone_target(cache_clean_target(aggregated));
    out->add_standalone_target(distclean_target(aggregated));

    /* A subproject's Makefile goes into its object directory, and a
     * configure is the first thing in a fresh checkout to want that
     * directory: nothing has been built yet, so nothing has made it.
     * Asked of the path that is about to be written rather than of
     * the object directory itself, so that whatever OBJDIR says is
     * what gets created. */
    const auto path = makefile_path();
    const auto slash = path.rfind('/');
    if (slash != std::string::npos)
        file_utils::mkdir_p(path.substr(0, slash));

    out->write_to_file(path);

    write_bootstrap_makefile();
    write_check_scopes(*out);
}

void project::check_target_shape(const context::ptr& ctx,
                                 std::map<std::string, context::ptr>& seen)
{
    /* Only the things that get linked, since they're the ones where
     * both of these questions have an answer.  A HEADERS is installed
     * rather than built, and a GENERATE writes its own source. */
    if (ctx->check_type({context_type::BINARY,
                         context_type::LIBRARY,}) == false)
        return;

    /* A target with no sources is a link with nothing to link, which
     * fails when make finally gets there with a message from the
     * linker about a missing main rather than anything that points at
     * the Configfile.  The usual way to arrive here is a SRCDIR or a
     * LIBDIR written between the target and its sources: both of
     * those go back to the top of the project, which closes the
     * target above them. */
    auto sources = false;
    for (const auto& child: ctx->children)
        if (child->check_type({context_type::SOURCE}) == true)
            sources = true;

    if (sources == false)
        ctx->strictness.complain(
            strict_since::v0_13(),
            ctx->cmd->debug(),
            "'" + ctx->cmd->data() + "' has nothing to build: no SOURCES"
            " ever landed on it",
            "give it at least one SOURCES, and check that nothing in"
            " between closed it first -- a SRCDIR or a LIBDIR goes back"
            " to the top of the project and ends the target above it");

    /* Two targets that come out in the same place are one target,
     * and only one set of rules can come out of that.  Which way it
     * goes wrong depends on whether the two were described the same
     * way: rules that match are folded together, so the second target
     * goes nowhere and it looks exactly like it worked, and rules
     * that don't match stop the build with an internal-sounding
     * complaint that names neither line.  Saying so here is worth it
     * for the second case alone, since it's the one where the only
     * other thing anybody gets is "Mismatched recipe for targets with
     * same name".
     *
     * Judged on the path normalized, because that is what decides
     * whether two names are one file.  The target's own name already
     * arrives that way from command_processor, but the directory it
     * lands in is whatever a LIBDIR said, and "lib" and "./lib" are as
     * much one place as "main" and "./main" are. */
    auto dir = ctx->check_type({context_type::LIBRARY})
        ? ctx->lib_dir
        : ctx->bin_dir;
    auto output = file_utils::normalize_path(dir + "/" + ctx->cmd->data());

    auto found = seen.find(output);
    if (found != seen.end())
        ctx->strictness.complain(
            strict_since::v0_13(),
            ctx->cmd->debug(),
            "'" + output + "' was already asked for on "
            + std::to_string(found->second->cmd->debug())
            + ", and two targets that come out in the same place are one"
            " target",
            "give one of them a different name, or delete the duplicate --"
            " only one set of rules can come out, so the other is lost,"
            " and if the two disagree at all the build stops here");

    /* Two targets can also fight over one path without either of
     * them naming it exactly: "BINARIES += tools" builds the file
     * bin/tools, and "BINARIES += tools/run" needs bin/tools to be the
     * directory it lands in.  No order of the two rules makes both of
     * those true, and the failure make arrives at says nothing about
     * why -- an "mkdir" refusing to replace a file with a directory,
     * or worse, an "mv" that finishes copying bin/tools into place by
     * moving it into the directory the other rule made, so the build
     * succeeds with no bin/tools program at all.
     *
     * This one is always an error rather than a strictness warning
     * like the one above.  An exact duplicate can at least come out as
     * one working target when the two lines agree; a file and a
     * directory at one path can't come out as anything.
     *
     * Asked both ways, since either line can come first: the paths
     * above this one that are already some target's file, and the
     * targets already filed under this one as a directory.  The second
     * is a range of the map starting at "<output>/", which is exactly
     * the paths inside it and none of the ones that merely share the
     * name as a prefix -- "tools-run" and "tools.d/run" sort apart
     * from "tools/". */
    auto refuse_nesting = [&](const std::string& file,
                              const context::ptr& file_ctx,
                              const std::string& inside,
                              const context::ptr& inside_ctx)
        {
            std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                      << "  error: '" << file << "' is the file built by "
                      << std::to_string(file_ctx->cmd->debug())
                      << ", but '" << inside << "', built by "
                      << std::to_string(inside_ctx->cmd->debug())
                      << ", needs it to be a directory\n"
                      << "  one path can't be both a file and a"
                      << " directory, so rename one of the two targets"
                      << " so that neither comes out inside the other"
                      << " -- 'tools' and 'tools-run', say, rather than"
                      << " 'tools' and 'tools/run'\n";
            abort();
        };

    for (auto slash = output.find('/');
         slash != std::string::npos;
         slash = output.find('/', slash + 1)) {
        auto parent = seen.find(output.substr(0, slash));
        if (parent != seen.end())
            refuse_nesting(parent->first, parent->second, output, ctx);
    }

    auto below = seen.lower_bound(output + "/");
    if (below != seen.end() && below->first.compare(0, output.size() + 1,
                                                    output + "/") == 0)
        refuse_nesting(output, ctx, below->first, below->second);

    seen[output] = ctx;
}

void project::check_generate_names(
    const context::ptr& ctx,
    std::map<std::string, std::pair<context::ptr, std::string>>& claimed)
{
    if (ctx->check_type({context_type::GENERATE}) == false)
        return;

    /* A GENERATE does not just write its output: it writes the output
     * through a temporary beside it, and keeps a dependency fragment
     * and a record of the recipe that wrote the fragment beside it too,
     * all named after the output.  Nothing stops a second GENERATE's
     * output from having one of those names, and when one does, two
     * rules own one file.
     *
     * Neither way round is something that can be made to work.  An
     * output named after another's fragment is two different rules for
     * one target, which used to stop pconfigure dead with no message at
     * all; an output named after another's temporary is moved or
     * deleted by every regeneration of the other, so with -j2 every
     * other build ended with it missing and the next make made it
     * again.  Moving the scratch files somewhere no output can be named
     * was the alternative, and it was not taken: the fragment's path
     * is in every Makefile already written and in every tree already
     * built, and a collision this rare is better answered with a
     * sentence than with a new layout everybody has to migrate to.
     *
     * The paths are compared normalized, so that "./gen.h.d" is caught
     * as surely as "gen.h.d", and it is the later of the two lines that
     * is refused whichever of them owns the scratch file -- the only
     * order a reader can predict without knowing which name is which. */
    auto output = ctx->gen_dir + "/" + ctx->cmd->data();

    auto mine = std::vector<std::pair<std::string, std::string>>{
        {output, "the output"}
    };
    for (const auto& scratch: language_gen_proc::scratch_files(ctx, output))
        mine.push_back(scratch);

    for (const auto& path: mine) {
        auto key = file_utils::normalize_path(path.first);
        auto found = claimed.find(key);
        if (found == claimed.end())
            continue;

        /* One path in the same role for both lines means one output
         * asked for twice, however it was spelled, and that comes out
         * as one set of identical rules.  Whether that deserves a word
         * is somebody else's question, and not the collision this is
         * about. */
        if (found->second.second == path.second)
            continue;

        std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                  << "  error: '" << key << "' is "
                  << path.second << " of this GENERATE, and it is already "
                  << found->second.second << " of the GENERATE on "
                  << std::to_string(found->second.first->cmd->debug())
                  << "\n"
                  << "  a GENERATE keeps '<name>.tmp', '<name>.d',"
                  << " '<name>.d.raw', '<name>.d.tmp' and"
                  << " '<name>.d-context' beside its output, so rename one"
                  << " of the two outputs so that neither is the other's"
                  << " name with one of those on the end\n";
        abort();
    }

    /* Two lines can fight over one path without either naming it
     * exactly, since every output lands in the one generated-files
     * directory: "GENERATE += sub/x.h" needs obj/proc/sub to be a
     * directory, and "GENERATE += sub" needs it to be a file.  So does
     * "GENERATE += gen.h.d/inner.h" next to "GENERATE += gen.h", whose
     * dependency fragment is obj/proc/gen.h.d.  Neither order works.
     * With the directory first, the other output is never written at
     * all -- its script only runs when the output is missing, and the
     * directory is there -- so the build goes green without it; with
     * the file first, the "mkdir" fails with a message that sends the
     * reader off to check permissions and doesn't name the other line.
     *
     * Asked both ways, as the target-shape check asks it for BINARIES:
     * the paths above each of this line's files that are already
     * another line's file, and the other lines' files already filed
     * under one of this line's as a directory.  The second is the range
     * of the map from "<path>/", which holds exactly the paths inside
     * it and none that merely share its name as a prefix. */
    auto refuse_nesting = [&](const std::string& file,
                              const std::string& file_role,
                              const context::ptr& file_ctx,
                              const std::string& inside,
                              const std::string& inside_role,
                              const context::ptr& inside_ctx)
        {
            std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                      << "  error: '" << file << "' is " << file_role
                      << " of the GENERATE on "
                      << std::to_string(file_ctx->cmd->debug())
                      << ", but '" << inside << "' is " << inside_role
                      << " of the GENERATE on "
                      << std::to_string(inside_ctx->cmd->debug())
                      << ", which needs it to be a directory\n"
                      << "  one path can't be both a file and a"
                      << " directory, so rename one of the two outputs so"
                      << " that neither it nor the '<name>.tmp',"
                      << " '<name>.d', '<name>.d.raw', '<name>.d.tmp' and"
                      << " '<name>.d-context' kept beside it comes out"
                      << " inside the other -- 'sub.h' and 'sub/x.h',"
                      << " say, rather than 'sub' and 'sub/x.h'\n";
            abort();
        };

    for (const auto& path: mine) {
        auto key = file_utils::normalize_path(path.first);

        for (auto slash = key.find('/');
             slash != std::string::npos;
             slash = key.find('/', slash + 1)) {
            auto parent = claimed.find(key.substr(0, slash));
            if (parent != claimed.end())
                refuse_nesting(parent->first, parent->second.second,
                               parent->second.first,
                               key, path.second, ctx);
        }

        auto below = claimed.lower_bound(key + "/");
        if (below != claimed.end()
            && below->first.compare(0, key.size() + 1, key + "/") == 0)
            refuse_nesting(key, path.second, ctx,
                           below->first, below->second.second,
                           below->second.first);
    }

    for (const auto& path: mine)
        claimed[file_utils::normalize_path(path.first)]
            = std::make_pair(ctx, path.second);
}

/* The whole of a file, or nothing when it can't be read: the one
 * question asked of it below is whether it says the same as another,
 * and a file that can't be read doesn't. */
static bool read_whole_file(const std::string& path, std::string& out)
{
    auto file = fopen(path.c_str(), "rb");
    if (file == NULL)
        return false;

    out.clear();
    char buffer[4096];
    size_t got;
    while ((got = fread(buffer, 1, sizeof(buffer), file)) > 0)
        out.append(buffer, got);

    auto ok = ferror(file) == 0;
    fclose(file);
    return ok;
}

void project::check_header_copy(const context::ptr& ctx)
{
    if (ctx->check_type({context_type::HEADER}) == false)
        return;

    context::ptr source = NULL;
    for (const auto& child: ctx->children)
        if (child->type == context_type::SOURCE) {
            source = child;
            break;
        }

    /* A HEADERS with nothing under it reads the header out of the
     * include directory where somebody put it, and copies nothing
     * there; it is the spelling this refusal points at, not one it is
     * about. */
    if (source == NULL)
        return;

    auto copy = file_utils::normalize_path(ctx->bin_dir + "/"
                                           + ctx->cmd->data());
    auto from = file_utils::normalize_path(source->src_dir + "/"
                                           + source->cmd->data());

    /* The copy is build output twice over: it is written over whenever
     * the source is newer, while configuring as well as by make, and
     * "make distclean" removes it by name -- see distclean_files().
     * Both are right about a file this build made and wrong about any
     * other, and the other there is to be wrong about is one a source
     * directory and an include directory can share.  With "SRCDIR =
     * include" a HEADERSRC's source and its copy are one path: make
     * drops the rule as a circular dependency on every run, and
     * distclean deletes the only copy of the header there is.
     *
     * Compared as the same file on disk as well as by name, so that a
     * symbolic link between the two directories is caught along with
     * the plain spelling. */
    struct stat cs, fs;
    auto same = copy == from;
    if (same == false
        && stat(copy.c_str(), &cs) == 0 && stat(from.c_str(), &fs) == 0)
        same = cs.st_dev == fs.st_dev && cs.st_ino == fs.st_ino;

    auto written = std::to_string(ctx->cmd->written_as());
    auto headersrc = ctx->cmd->written_as() == command_type::HEADERSRC;
    auto instead = headersrc
        ? std::string("write 'HEADERS += ") + ctx->cmd->data()
              + "' instead, with no SOURCES under it,"
        : std::string("delete the SOURCES under it,");

    if (same == true) {
        std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
                  << "  error: this " << written << " copies '" << from
                  << "' onto itself: its source directory and the include"
                  << " directory are the same place\n"
                  << "  make drops a rule whose target is its own"
                  << " source, and 'make distclean' removes the copies"
                  << " a HEADERS makes -- which here is the header"
                  << " itself\n"
                  << "  " << instead << " to install the header from"
                  << " where it already is\n";
        abort();
    }

    /* Nothing there, nothing to lose. */
    if (access(copy.c_str(), F_OK) != 0)
        return;

    /* Something there is either a copy this build made earlier or a
     * header somebody wrote, and only the second is a problem: this
     * configure would write over it if the source is newer, make would
     * leave it alone and compile against it if it isn't, and distclean
     * deletes it either way.
     *
     * A copy is known by one of two things.  Every configure that
     * wrote the rule also wrote the record of its recipe in the object
     * directory, and "make clean", which is what takes the copy away,
     * takes the record with it -- see language_bash::targets() -- so
     * a record that is there vouches for a copy that is there.  That
     * is not proof against a copy deleted by hand with the record left
     * behind, and then a header written in its place; but "make clean"
     * is how a build tree is emptied, and it used to leave the record,
     * so that a header written after it was vouched for and then
     * deleted by distclean.
     *
     * A copy whose record is gone -- an object directory deleted by
     * hand, an OBJDIR moved, a tree configured by a pconfigure from
     * before records were kept -- still says exactly what its source
     * says, since phc copies byte for byte.  What is left is a file
     * with no record that says something else, and that is refused
     * even though it could be a copy whose record was lost and whose
     * source was edited since: telling the two apart would take
     * knowing what the file was before the edit, and the cost of the
     * wrong guess is one rm on one side and a lost header on the
     * other.  So the message owns up to both, and says which rm. */
    auto record = language::recipe_record_path(ctx, copy);
    if (access(record.c_str(), F_OK) == 0)
        return;

    auto copy_says = std::string();
    auto from_says = std::string();
    if (read_whole_file(copy, copy_says) && read_whole_file(from, from_says)
        && copy_says == from_says)
        return;

    std::cerr << std::to_string(ctx->cmd->debug()) << "\n"
              << "  error: '" << copy << "' is already there, and this "
              << written << " would make it a copy of '" << from << "'\n"
              << "  there is no record that this build made it, and it"
              << " doesn't say what '" << from << "' says: it is either"
              << " a header somebody wrote or an old copy whose record"
              << " was lost, as when the object directory is deleted"
              << " after '" << from << "' was edited\n"
              << "  the copy is build output: it is written over whenever"
              << " '" << from << "' is newer, and 'make distclean'"
              << " removes it\n"
              << "  if '" << copy << "' is the header to install, "
              << instead << " to install it from where it is; if '"
              << from << "' is, delete '" << copy << "', or move it out"
              << " of the way if it holds anything worth keeping, and"
              << " configure again\n";
    abort();
}

void project::write_check_records(const std::vector<ptr>& aggregated) const
{
    write_check_dirs(aggregated);
    write_check_stamp();
}

void project::write_check_stamp(void) const
{
    const auto& root = _processor->root_context();

    const auto& suite = _processor->default_test_suite();
    auto stamp = suite.size() > 0
               ? root->obj_dir + "/check-suite-" + suite + "-done"
               : root->obj_dir + "/check-all-done";

    /* Through write_configure_output(), so that the Makefile carries a
     * rule that writes it again: this lives in the object directory,
     * and a deleted one used to take it along for good, leaving ptest
     * to guess "check-all-done" -- a stamp a project with a
     * DEFAULT_TEST_SUITE never builds, so every ptest after warned
     * that "make check" was out of date however recently it ran. */
    auto path = root->obj_dir + "/check-stamp";
    file_utils::mkdir_p(root->obj_dir);
    if (file_utils::write_configure_output(path,
                                           root->unbased(stamp) + "\n"))
        return;

    std::cerr << "can't write '" << path << "': "
              << strerror(errno) << "\n"
              << "  this is where the stamp \"make check\" builds gets"
              << " written down,\n"
              << "  and \"ptest\" needs it to say whether its report is"
              << " current\n";
    abort();
}

void project::write_check_scopes(const makefile::makefile& out) const
{
    for (const auto& scope: out.check_scopes()) {
        if (file_utils::write_if_changed(scope.first, scope.second))
            continue;

        std::cerr << "can't write '" << scope.first << "': "
                  << strerror(errno) << "\n"
                  << "  this is where the tests a \"make check\" covers get"
                  << " written down,\n"
                  << "  and make needs it to know when that has changed\n";
        abort();
    }
}

std::string project::base_suffix(const std::string& base)
{
    auto out = std::string();

    /* The '.' goes in when the next name arrives rather than when the
     * separator does, so that the '/' every base is spelled with on
     * the end doesn't leave one dangling -- and so that the leading
     * one is there for free.  Every caller is sticking this on the
     * end of a name it already has, and the project at the top of the
     * run sticks nothing on at all. */
    auto pending = base.size() > 0;
    for (const auto& c: base) {
        if (c == '/') {
            pending = out.size() > 0;
            continue;
        }

        if (pending == true) {
            out += '.';
            pending = false;
        }

        out += c;
    }

    return out;
}

std::string project::makefile_path(void) const
{
    /* A project a parent pulled in writes into its own object
     * directory rather than to the Makefile at the top of it, because
     * that Makefile belongs to a pconfigure run standing down there.
     *
     * Both files are right, and they say different things.  From up
     * here the subproject is one piece of a bigger build: every path
     * in it goes through a variable so the parent can put a directory
     * on the front, and the things it depends on that live outside it
     * are in there too.  From down there it is the whole build, its
     * paths mean what they say, and it has never heard of anything
     * above it.  One name for both meant whichever configure ran last
     * won, and the build that lost broke the next time somebody ran
     * make -- for the parent by quietly building the subproject into
     * the parent's own directories, which is a wrong answer that
     * looks like a build.
     *
     * So the parent's copy goes somewhere a build from inside has no
     * opinion about.  The object directory is already where a
     * configure leaves files for a build to read, already ignored by
     * revision control, and already what "make distclean" takes
     * away. */
    if (_base.size() > 0)
        return _processor->root_context()->obj_dir
             + "/Makefile" + base_suffix(_base);

    /* A project that bootstraps its own pconfigure has a Makefile
     * already, written once and committed, and make is run at that
     * one.  What comes out of a configure goes beside it under a name
     * that says who wrote it. */
    if (_processor->bootstrap().size() > 0)
        return _base + "Makefile.pconfigure";

    return _base + "Makefile";
}

std::string project::makefile_include(void) const
{
    /* Through this project's own variable, the way a parent names
     * anything else of a subproject's.  The include has to resolve
     * from wherever make was started, and by then the only thing that
     * knows where this project is sitting is the variable the parent
     * set.
     *
     * Asked of the finished path rather than built back up out of the
     * pieces, so that an OBJDIR pointing somewhere outside the
     * project still comes out right: a path that isn't in here is one
     * the rewrite leaves alone, which is exactly what should happen
     * to it. */
    return makefile::path_prefix(_base, prefix_variable(_base))
        .rewrite(makefile_path());
}

void project::write_bootstrap_makefile(void) const
{
    const auto& srcpath = _processor->bootstrap();
    if (srcpath.size() == 0)
        return;

    /* Spelled ending in a '/', the way every directory in a run is,
     * so that sticking a name on the end of the variable is all
     * anybody has to do with it. */
    auto out = std::string();
    out += "# Written by pconfigure, and meant to be committed.\n";
    out += "#\n";
    out += "# Everything in here comes from the BOOTSTRAP line of a"
           " Configfile, so it\n";
    out += "# says the same thing today that it said when it was"
           " written down.  The rest\n";
    out += "# of the build -- the part that changes when a Configfile"
           " does -- is in\n";
    out += "# " + _base + "Makefile.pconfigure, which pconfigure writes"
           " and this file includes.\n";
    out += "#\n";
    out += "# What it is for is the first \"make\" in a fresh checkout,"
           " which has no\n";
    out += "# pconfigure to write that file with.  The rules below"
           " build one out of the\n";
    out += "# vendored source, so nobody has to be told that"
           " pconfigure exists before\n";
    out += "# they can build this project.\n";
    out += "\n";

    /* The same cancellations makefile::write_to_file() writes, said
     * again here because of when they are needed.  make remakes what
     * it includes before it has read it, so during the one phase that
     * decides whether to run pconfigure at all, the file below has
     * not been read yet and this is the only Makefile in play --
     * which is exactly the phase where make would otherwise go
     * looking for a built-in rule to build a Makefile with. */
    out += "# make ships rules that build a file out of another file"
           " sitting next to it,\n";
    out += "# and they fire on anything that has no rule of its own."
           "  A Makefile is a\n";
    out += "# thing make tries to build before it reads it, so"
           " cancelling them has to\n";
    out += "# happen here rather than only in the file this one"
           " includes.\n";
    for (const auto& suffix: {"c", "C", "cc", "cpp", "f", "F", "m",
                              "mod", "o", "p", "r", "s", "S", "sh"})
        out += "%: %." + std::string(suffix) + "\n";
    out += "%:: %,v\n";
    out += "%:: RCS/%,v\n";
    out += "%:: RCS/%\n";
    out += "%:: s.%\n";
    out += "%:: SCCS/s.%\n";
    out += ".SUFFIXES:\n";
    out += "\n";

    /* The same "unexport CDPATH" as makefile::write_to_file(), and
     * needed here for the same reason the cancellations above are:
     * the rules below run before Makefile.pconfigure has been read.
     * Their "cd $(PCONFIGURE_SRCPATH)" is the BOOTSTRAP line as the
     * Configfile spelled it, which is relative, and under a CDPATH
     * with another checkout of the same project on it a fresh build
     * would bootstrap the pconfigure over there instead. */
    out += "# A CDPATH from the shell make was started in would send"
           " the cd into the\n";
    out += "# vendored tree below to any other directory of the same"
           " name along it.\n";
    out += "unexport CDPATH\n";
    out += "\n";

    out += "PCONFIGURE_SRCPATH  = " + srcpath + "\n";
    out += "PCONFIGURE          = $(PCONFIGURE_SRCPATH)bin/pconfigure\n";
    out += "\n";
    out += "# make remakes what it includes before it reads it, so"
           " this is where the\n";
    out += "# whole build arrives -- and the first target in it,"
           " \"all\", is what a\n";
    out += "# \"make\" with nothing after it means.\n";
    out += "include Makefile.pconfigure\n";
    out += "\n";
    /* After the include and not before it, which is the whole of what
     * this line has to get right.  Makefile.pconfigure says which
     * options the tree was configured with, and every run of
     * pconfigure below hands those back -- the one AUTORECONFIGURE
     * sets off most of all, which comes from a make nobody gave any
     * options to.  Said first, this line made the variable empty
     * before that file was read, and the "?=" there found it already
     * set: a tree whose first make was given "--config debug" lost it
     * the first time a Configfile changed. */
    out += "# Makefile.pconfigure says which options this tree was"
           " configured with, so\n";
    out += "# that running pconfigure again runs it the same way."
           "  This is only for the\n";
    out += "# first make, which has no Makefile.pconfigure yet: give"
           " PCONFIGURE_ARGS to\n";
    out += "# make to configure with options, then or later.\n";
    out += "PCONFIGURE_ARGS    ?=\n";
    out += "\n";
    out += "# Written when it isn't there, and left alone once it is."
           "  What a Makefile\n";
    out += "# says is what the Configfiles said the last time somebody"
           " ran pconfigure,\n";
    out += "# here as everywhere else: the prerequisite is order-only"
           " because this is\n";
    out += "# about the file existing and not about it being newer"
           " than anything.\n";
    out += "#\n";
    out += "# The recipe checks for its own pconfigure because"
           " \"make clean\" deletes it,\n";
    out += "# and a rule that runs a binary the build has just"
           " removed is a tree that\n";
    out += "# cannot be built out of again.  The vendored source is"
           " right there, so\n";
    out += "# there is no reason for that to be anything worse than"
           " a slow build.\n";
    out += "Makefile.pconfigure: | $(PCONFIGURE_SRCPATH)Makefile\n";

    /* "@+" is two prefixes and not a typo.  The "+" says the line is
     * recursive, which is what hands bootstrap.sh's make the
     * jobserver rather than leaving it to build a whole project at
     * -j1, and it has to survive anybody tidying this up.  The "@"
     * says make should not read the line out first, which every other
     * recipe in every Makefile pconfigure writes already does: a
     * build says "CC", "LD", "CP" and gets on with it.  Without the
     * "@" the first thing anybody saw of a build was a line of shell
     * about a file they had never heard of, on every single make,
     * whether or not it went on to do anything.
     *
     * The announcement is inside the "||" rather than on a line of
     * its own because this recipe runs on every build -- the file it
     * writes is one make includes, so make remakes it before it can
     * read it -- and the ordinary case, where a pconfigure is already
     * there, has nothing to report.  It is worth reporting in the
     * other case: a bootstrap is half a minute of somebody else's
     * build arriving in the middle of this one, and a build that goes
     * quiet for that long and then prints a wall of "CC" lines from a
     * project nobody asked about is harder to read than one that says
     * whose they are.
     *
     * ";" rather than "&&" after the echo, because the point of the
     * line is to bootstrap: an echo that could not write is no reason
     * to skip it, and this way the status make grades is the one
     * bootstrap.sh exited with. */
    out += "\t@+test -x $(PCONFIGURE) ||"
           " (echo \"BOOTSTRAP\t$(PCONFIGURE_SRCPATH)\";"
           " cd $(PCONFIGURE_SRCPATH) && ./bootstrap.sh)\n";
    out += "\t@echo \"PCONFIGURE\"\n";
    out += "\t@$(PCONFIGURE) $(PCONFIGURE_ARGS)\n";
    out += "\n";
    out += "# Asking for it again, which is the other half of that:"
           " the build doesn't\n";
    out += "# decide when a tree gets reconfigured, so there has to be"
           " a way to say so.\n";
    out += "# This is the same rule every pconfigure project has,"
           " pointed at the\n";
    out += "# pconfigure this one builds rather than at the PATH.\n";
    out += ".PHONY: reconfigure\n";
    out += "reconfigure: $(PCONFIGURE)\n";
    out += "\t@echo \"PCONFIGURE\"\n";
    out += "\t@$(PCONFIGURE) $(PCONFIGURE_ARGS)\n";
    out += "\n";
    out += "# The one thing that can't be done by a build: the first"
           " run has no\n";
    out += "# pconfigure to configure anything with, so the vendored"
           " tree builds one\n";
    out += "# straight from its own source.  Its Makefile is what says"
           " that has\n";
    out += "# happened, because bootstrap.sh is what writes it.\n";
    out += "#\n";
    out += "# After that the tree is an ordinary subproject."
           "  Makefile.pconfigure\n";
    out += "# includes the Makefile below and builds the pconfigure in"
           " it out of the\n";
    out += "# same dependency graph as everything else, which is why"
           " nothing here\n";
    out += "# recurses into it on every build.\n";
    out += "$(PCONFIGURE_SRCPATH)Makefile:\n";

    /* Announced the same way as the check above, and for the same
     * reason -- but from a line of its own, since a rule that exists
     * only to bootstrap has no ordinary case to stay quiet for.  Only
     * one of the two ever says it on a given build: this one runs on
     * a fresh checkout, and by the time the check above is reached
     * there is a pconfigure for it to find. */
    out += "\t@echo \"BOOTSTRAP\t$(PCONFIGURE_SRCPATH)\"\n";
    out += "\t@+cd $(PCONFIGURE_SRCPATH) && ./bootstrap.sh\n";

    /* Written only when it would say something new, because this is
     * the file make was started on: rewriting it on every configure
     * would hand make a Makefile newer than everything it just built,
     * and would show up as a change in every commit that touched a
     * Configfile. */
    auto path = _base + "Makefile";
    if (file_utils::write_if_changed(path, out))
        return;

    std::cerr << "can't write '" << path << "': "
              << strerror(errno) << "\n"
              << "  this is the Makefile the BOOTSTRAP on "
              << std::to_string(_processor->bootstrap_cmd()->debug())
              << " asked for,\n"
              << "  and it's the one make gets run at\n";
    abort();
}

void project::write_configureopts(void) const
{
    /* Every vendored tree belongs to exactly the project whose
     * Configfile pulled it in, which is the same project whose
     * Makefile got its rules -- so walking this project's own list
     * writes each tree's file exactly once, from the same place the
     * rule that reads it was written. */
    for (const auto& vendored: _processor->vendored()) {
        const auto& path = vendored->configureopts_file();
        if (path.size() == 0)
            continue;

        if (file_utils::write_configure_output(
                path, vendored->configure_signature()))
            continue;

        std::cerr << "can't write '" << path << "': "
                  << strerror(errno) << "\n"
                  << "  this is where the options the vendored tree in '"
                  << vendored->source_dir() << "' was configured with get"
                  << " written down,\n"
                  << "  and make needs it to know when they've changed\n";
        abort();
    }
}

void project::write_check_dirs(const std::vector<ptr>& aggregated) const
{
    const auto& root = _processor->root_context();

    /* Written the way whoever reads it will be standing: "ptest" runs
     * where make runs, which for this file is this project.  A project
     * that said ABRT_IS_FAIL has that after a tab, so a bare "ptest"
     * scores its results the way "make report" does. */
    auto out = std::string();
    for (const auto& project: aggregated) {
        if (project->has_check_dir() == false)
            continue;
        out += root->unbased(
                   project->processor()->root_context()->check_dir);
        if (project->processor()->abrt_is_fail())
            out += "\tabrt-is-fail";
        out += "\n";
    }

    /* The Makefile is what creates this directory during a build, and
     * nothing has been built yet.  And through write_configure_output()
     * because the object directory is a thing people delete: without
     * a rule to write it again, the next ptest found only this
     * project's results, missed every subproject's, and scored an
     * ABRT_IS_FAIL project's aborts as errors. */
    auto path = root->obj_dir + "/check-dirs";
    file_utils::mkdir_p(root->obj_dir);
    if (file_utils::write_configure_output(path, out))
        return;

    std::cerr << "can't write '" << path << "': "
              << strerror(errno) << "\n"
              << "  this is where the test results of every project this"
              << " one covers get written down,\n"
              << "  and \"ptest\" needs it to find them\n";
    abort();
}

bool project::has_check_dir(void) const
{
    /* The same question distclean_dirs() asks before it names the
     * directory, so that what the report reads as results and what
     * distclean takes away as results are one directory or neither.
     * Asked of everything built rather than only of the tests, since
     * a project whose last test was just deleted still has that
     * test's stale result in there, and a report that stopped looking
     * would quietly drop it rather than show it. */
    return _processor->output_contexts().size() > 0;
}
