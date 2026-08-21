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

#ifndef PROJECT_HXX
#define PROJECT_HXX

#include "command_processor.h++"
#include <libmakefile/implied_deps.h++>
#include <libmakefile/makefile.h++>
#include <map>
#include <memory>
#include <string>
#include <vector>

/* Everything that comes out of one project's Configfiles: the targets
 * they describe, what those targets offer each other, and the Makefile
 * they all get written to.
 *
 * A pconfigure run has one of these per project, so there's nothing
 * here that a second project in the same run would trip over. */
class project {
public:
    typedef std::shared_ptr<project> ptr;

private:
    const std::string _base;
    const command_processor::ptr _processor;

    /* The targets, in the order they were generated -- which is the
     * order they get written out in, so it has to be stable. */
    std::vector<makefile::target::ptr> _targets;
    std::map<std::string, makefile::target::ptr> _by_name;

    std::vector<makefile::capability> _provided;
    std::vector<makefile::capability> _needed;

public:
    project(const std::string& base,
            const command_processor::ptr& processor);
    virtual ~project(void) {}

public:
    /* Accessor methods. */
    const std::string& base(void) const { return _base; }
    const command_processor::ptr& processor(void) const { return _processor; }
    const std::vector<makefile::target::ptr>& targets(void) const
        { return _targets; }
    const std::vector<makefile::capability>& provided(void) const
        { return _provided; }
    const std::vector<makefile::capability>& needed(void) const
        { return _needed; }

    /* The Makefile this project gets written to. */
    std::string makefile_path(void) const { return _base + "Makefile"; }

public:
    /* Turns this project's contexts into targets, asking each
     * context's language what its targets offer and want along the
     * way. */
    void generate_targets(void);

    /* Writes this project's Makefile, along with whichever of the
     * dependencies that were worked out across the whole run belong
     * in it. */
    void write_makefile(const std::vector<makefile::implied_dep>& implied) const;

private:
    /* The targets that don't come from any context: cleaning out the
     * object cache, and undoing a configure. */
    makefile::target::ptr cache_clean_target(void) const;
    makefile::target::ptr distclean_target(void) const;
};

#endif
