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
#include <sys/stat.h>
#include <cctype>
#include <cerrno>
#include <cstring>
#include <functional>
#include <iostream>

project::project(const std::string& base,
                 const command_processor::ptr& processor)
: _base(base),
  _processor(processor)
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
        auto suffix = processor->take_pending_config();
        if (suffix.size() == 0)
            break;

        for (const auto& included: config_lines(processor->srcpath(),
                                                "Configfile",
                                                suffix))
            process_line(self, included, seen);
    }

    /* A subproject is read before the next line, so that the rest of
     * this Configfile can ask about what it builds. */
    while (true) {
        auto base = processor->take_pending_subproject();
        if (base.size() == 0)
            break;

        auto child = read(base, processor->root_context(), seen);
        if (child != NULL)
            self->_children.push_back(child);
    }
}

void project::read_file(const ptr& self,
                        const std::string& filename,
                        std::set<std::string>& seen)
{
    for (const auto& line: lines_from_file(self->_processor->srcpath(),
                                           filename))
        process_line(self, line, seen);
}

project::ptr project::read(const command_processor::ptr& processor,
                           std::set<std::string>& seen)
{
    auto out = std::make_shared<project>(processor->base(), processor);

    /* Anything the command line asked for comes first, since that's
     * the order it was processed in. */
    while (true) {
        auto suffix = processor->take_pending_config();
        if (suffix.size() == 0)
            break;

        for (const auto& line: config_lines(processor->srcpath(),
                                            "Configfile",
                                            suffix))
            process_line(out, line, seen);
    }

    for (const auto& filename: std::vector<std::string>{
             processor->srcpath() + "/Configfiles/local",
             processor->srcpath() + "/Configfile.local",
             processor->srcpath() + "/Configfiles/main",
             processor->srcpath() + "/Configfile"})
        read_file(out, filename, seen);

    out->generate_targets();
    return out;
}

project::ptr project::read(const std::string& base,
                           const context::ptr& defaults,
                           std::set<std::string>& seen)
{
    /* The path arrived normalized, and whether this is a pconfigure
     * project at all was decided before it got here: picking a build
     * system for a directory is what a SUBPROJECTS does, and only the
     * ones that turned out to be pconfigure projects come this way. */
    auto normalized = normalize_base(base);

    /* A project that two others both pull in is one project, and only
     * gets read once -- which is also what stops a project that
     * somehow reaches itself from recursing forever. */
    if (seen.insert(normalized).second == false)
        return NULL;

    auto processor = std::make_shared<command_processor>(normalized, defaults);
    return read(processor, seen);
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

void project::generate_targets(void)
{
    /* A vendored tree's rules belong to this project: the tree
     * already has a Makefile and it's the tree's own, so there's
     * nowhere else for them to go. */
    for (const auto& vendored: _processor->vendored())
        for (const auto& target: vendored->targets(_processor->vendored()))
            _targets.push_back(target);

    /* What each target this project builds is going to be called,
     * which is the only way to notice that two of them are going to
     * be called the same thing.  The name alone isn't enough: a
     * LIBDIR between two LIBRARIES lines makes two libraries with one
     * name and two homes, which is a thing somebody meant. */
    auto by_output = std::map<std::string, context::ptr>();

    for (const auto& context: _processor->output_contexts()) {
        if (context->debug == true)
            std::cerr << "Building Context: " << context->cmd->data() << "\n";

        check_target_shape(context, by_output);

        auto language = pick_language(context->languages, context);
        for (const auto& target: language->targets(context)) {
            auto found = _by_name.find(target->name());
            if (found == _by_name.end()) {
                if (context->debug == true)
                    std::cerr << "  target: " << target->name() << "\n";
                _targets.push_back(target);
            } else if (!same_recipe(found->second, target)) {
                std::cout << "Mismatched recipe for targets with same name\n";
                abort();
            }
            _by_name[target->name()] = target;

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

    /* Same reason: what an AUTODEPS = false was worth depends on
     * everything it reached, and one line reaches as far down the
     * file as the target it was written on goes. */
    check_autodeps();
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

            if (_processor->test_suites().size() == 1) {
                std::cerr << "  the only suite here is '"
                          << suite->name() << "'\n";
            } else {
                std::cerr << "  the suites here are:";
                for (const auto& other: _processor->test_suites())
                    std::cerr << " '" << other->name() << "'";
                std::cerr << "\n";
            }

            abort();
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

void project::check_test_order(void) const
{
    /* Every test this project runs, by the name of the target that
     * runs it -- which is exactly what a DEPTESTS resolves to, since
     * both of them are that test's check directory and its own name.
     *
     * A test is a child of the thing it exercises rather than an
     * output context of its own, so this has to go down and look:
     * asking only the contexts at the top would find no tests at all
     * and quietly approve every DEPTESTS in the project. */
    auto tests = std::map<std::string, context::ptr>();

    std::function<void(const context::ptr&)> gather =
        [&](const context::ptr& ctx)
        {
            if (ctx->check_type({context_type::TEST}) == true)
                tests[ctx->check_target()] = ctx;

            for (const auto& child: ctx->children)
                gather(child);
        };

    for (const auto& ctx: _processor->output_contexts())
        gather(ctx);

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
         * stale and throw away a build that's perfectly good. */
        auto prune = std::string();
        for (const auto& vendored: project->_processor->vendored())
            prune += " -not -path '" + vendored->output_dir() + "/*'";

        /* pconfigure wrote this one, and the Makefile says nothing
         * about it: reading the Makefile back would decide it was
         * stale and throw away the only record of where the test
         * results live. */
        prune += " -not -path '"
              + project->_processor->root_context()->obj_dir
              + "/check-dirs'";

        for (const auto& pair: obj_dirs) {
            const auto& dir = pair.first;

            /* '|' rather than '/' as the delimiter, since a directory
             * that has one in it would otherwise end the command. */
            commands.push_back(
                "comm -23 "
                "<(find " + dir + " -type f" + prune + " | sort) "
                "<(sed -n 's|\\(^" + dir + "/[^[:space:]:]*\\):.*|\\1|p' "
                + project->makefile_path() + " | sort -u) "
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

makefile::target::ptr project::distclean_target(const std::vector<ptr>& projects) const
{
    auto dirs = std::map<std::string, bool>();
    auto makefiles = std::vector<std::string>();
    for (const auto& project: projects) {
        /* Every project has an object directory whether or not it
         * builds anything, because pconfigure writes to it: the list
         * of where test results land goes there.  A project that only
         * pulls in other projects has no context to find that
         * directory through, so it gets named outright. */
        dirs[project->_processor->root_context()->obj_dir] = true;

        /* A vendored tree builds into this project's object
         * directory, so it's already covered by whatever covers that
         * -- but a project that vendors something and builds nothing
         * of its own has no contexts to find it through. */
        for (const auto& vendored: project->_processor->vendored())
            dirs[vendored->ctx()->obj_dir] = true;

        for (const auto& context: project->_processor->output_contexts()) {
            dirs[context->bin_dir] = true;
            dirs[context->check_dir] = true;
            dirs[context->lib_dir] = true;
            dirs[context->obj_dir] = true;
        }
        makefiles.push_back(project->makefile_path());
    }

    auto commands = std::vector<std::string>();
    for (const auto& pair: dirs)
        commands.push_back("rm -rf " + pair.first);
    for (const auto& path: makefiles)
        commands.push_back("rm -rf " + path);

    return std::make_shared<makefile::target>(
        "distclean",
        "DISTCLEAN",
        std::vector<makefile::target::ptr>{},
        std::vector<makefile::global_targets>{},
        commands,
        std::vector<std::string>{"distclean"}
    );
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
        out->add_subproject(prefix_variable(child->base()), child->base());

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
        out->add_check_dir(project->processor()->root_context()->check_dir);

    out->add_standalone_target(cache_clean_target(aggregated));
    out->add_standalone_target(distclean_target(aggregated));

    out->write_to_file(makefile_path());

    write_check_dirs(aggregated);
    write_configureopts();
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
     * same name". */
    auto dir = ctx->check_type({context_type::LIBRARY})
        ? ctx->lib_dir
        : ctx->bin_dir;
    auto output = dir + "/" + ctx->cmd->data();

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

    seen[output] = ctx;
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

        if (file_utils::write_if_changed(path,
                                         vendored->configure_signature()))
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

    /* The Makefile is what creates this directory during a build, and
     * nothing has been built yet. */
    mkdir(root->obj_dir.c_str(), 0777);

    auto path = root->obj_dir + "/check-dirs";
    auto file = fopen(path.c_str(), "w");
    if (file == NULL) {
        std::cerr << "Unable to open " << path << "\n";
        abort();
    }

    /* Written the way whoever reads it will be standing: "ptest" runs
     * where make runs, which for this file is this project. */
    for (const auto& project: aggregated)
        fprintf(file, "%s\n",
                root->unbased(
                    project->processor()->root_context()->check_dir).c_str());

    fclose(file);
}
