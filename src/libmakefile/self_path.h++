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

#ifndef LIBMAKEFILE__SELF_PATH_HXX
#define LIBMAKEFILE__SELF_PATH_HXX

#include <string>

namespace makefile {
    /* The absolute path of the directory that contains the currently-running
     * executable, with symlinks resolved.  Computed once and cached.  Returns
     * an empty string if the running executable's path cannot be determined. */
    const std::string& self_exec_dir(void);

    /* The command used to invoke one of pconfigure's own helper tools (ptest,
     * pbashc, phc, ...) from a generated Makefile.  Since these tools are
     * installed alongside pconfigure, we can name them by their absolute path
     * rather than relying on $PATH -- this way the tool that matches the
     * pconfigure generating the Makefile is always the one that runs.  Invoking
     * by absolute path keeps each tool's RPATH (which is relative to its own
     * location) resolving the correct libpconfigure.so.  Falls back to the bare
     * tool name if the running executable's location cannot be determined. */
    std::string tool_command(const std::string& tool_name);
}

#endif
