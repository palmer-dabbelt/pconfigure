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

    for (const auto& context: _processor->output_contexts()) {
        if (context->debug == true)
            std::cerr << "Building Context: " << context->cmd->data() << "\n";

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
                             const std::vector<ptr>& aggregated) const
{
    /* FIXME: If any target is verbose, then all are. */
    auto verbose = [&](void) -> bool {
        for (const auto& context: _processor->output_contexts())
            if (context->verbose == true)
                return true;
        return false;
        }();

    auto prefix = _base.size() == 0
        ? makefile::path_prefix()
        : makefile::path_prefix(_base, prefix_variable(_base));

    auto out = std::make_shared<makefile::makefile>(
        verbose,
        _processor->root_context()->obj_dir,
        prefix);

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
