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

    /* Where one of pconfigure's own helper tools (ptest, pbashc, phc, ...)
     * lives.  Since these tools are installed alongside pconfigure, we can
     * name them by their absolute path rather than relying on $PATH -- this
     * way the tool that matches the pconfigure generating the Makefile is
     * always the one that runs.  Invoking by absolute path keeps each tool's
     * RPATH (which is relative to its own location) resolving the correct
     * libpconfigure.so.  Falls back to the bare tool name if the running
     * executable's location cannot be determined.
     *
     * This is the path as a file name, for asking the filesystem about or
     * for writing down somewhere that isn't a recipe. */
    std::string tool_path(const std::string& tool_name);

    /* The same tool as a command, spelled for a recipe line.
     *
     * The directory is wherever somebody unpacked pconfigure, and nothing
     * about it was ever promised to be a single shell word: pasted in bare,
     * a pconfigure under "my tools/bin" wrote recipes the shell split in
     * two, so every script, every test and "make reconfigure" stopped on
     * "/x/my: No such file or directory", and one under "tools$x/bin" had
     * make expand "$x" out of the middle of it before the shell got that
     * far.  So it goes through recipe_quoted(), the same quoting a file
     * this Makefile writes goes through, and every caller that builds a
     * recipe out of it gets that for free.  Not for prerequisites, where
     * make wants the bare name -- that is what tool_path() is for. */
    std::string tool_command(const std::string& tool_name);
}

#endif
