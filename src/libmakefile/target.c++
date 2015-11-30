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
      _comment(comment)
{
}

makefile::target::target(const std::string& name)
    : _name(name),
      _short_cmd(),
      _deps(),
      _global(),
      _cmds(),
      _comment()
{
}

void makefile::target::write_to_file(FILE *file) const
{
    /* First write a little header that adds the upcoming target to
     * any of the global targets that it may have ended up setting. */
    for (const auto& global_target: _global) {
        switch (global_target) {
        case global_targets::ALL:
            fprintf(file, "all: %s\n", _name.c_str());
            break;
        case global_targets::CHECK:
            fprintf(file, "check: %s\n", _name.c_str());
            break;
        case global_targets::CLEAN:
            fprintf(file, ".PHONY: __pconfigure__clean-%s\n", _name.c_str());
            fprintf(file, "__pconfigure__clean-%s:; rm -f %s\n",
                    _name.c_str(), _name.c_str());
            fprintf(file, "clean: __pconfigure__clean-%s\n", _name.c_str());
            break;
        case global_targets::INSTALL:
            fprintf(file, "install: %s\n", _name.c_str());
            break;
        case global_targets::UNINSTALL:
            fprintf(file, ".PHONY: __pconfigure__uninstall-%s\n", _name.c_str());
            fprintf(file, "__pconfigure__uninstall-%s:; rm -f %s\n",
                    _name.c_str(), _name.c_str());
            fprintf(file, "uninstall: __pconfigure__uninstall-%s\n", _name.c_str());
            break;
         }
    }

    /* This actually writes out the make rule that's necessary  */
    for (const auto& comment: _comment)
        fprintf(file, "# %s\n", comment.c_str());
    fprintf(file, "%s:", _name.c_str());
    for (const auto& dep: _deps)
        fprintf(file, " %s", dep->_name.c_str());
    fprintf(file, "\n");
    fprintf(file, "\t@echo \"%s\"\n", _short_cmd.c_str());
    for (const auto& cmd: _cmds)
        fprintf(file, "\t@%s\n", cmd.c_str());
    fprintf(file, "\n");
}
