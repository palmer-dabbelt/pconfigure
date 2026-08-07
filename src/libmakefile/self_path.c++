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

#include "self_path.h++"
#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
#include <libgen.h>
#include <vector>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

namespace {
    /* The path to the running executable, as reported by the OS.  This may
     * still be relative or contain symlinks/"."/".." -- self_exec_dir()
     * canonicalizes it. */
    std::string running_exec_path(void)
    {
#ifdef __APPLE__
        uint32_t size = 0;
        _NSGetExecutablePath(NULL, &size);
        std::vector<char> buf(size + 1);
        if (_NSGetExecutablePath(&buf[0], &size) != 0)
            return "";
        return std::string(&buf[0]);
#else
        std::vector<char> buf(PATH_MAX);
        ssize_t len = readlink("/proc/self/exe", &buf[0], buf.size());
        if (len < 0)
            return "";
        return std::string(&buf[0], len);
#endif
    }

    std::string compute_self_exec_dir(void)
    {
        auto raw = running_exec_path();
        if (raw.empty())
            return "";

        /* Resolve symlinks and "."/".." so the RPATH baked into the sibling
         * tools -- which is relative to their own location -- keeps finding the
         * matching libpconfigure.so. */
        char resolved[PATH_MAX];
        std::string full = (realpath(raw.c_str(), resolved) != NULL)
            ? std::string(resolved)
            : raw;

        /* dirname() is allowed to modify its argument, so hand it a copy. */
        std::vector<char> copy(full.begin(), full.end());
        copy.push_back('\0');
        return std::string(dirname(&copy[0]));
    }
}

namespace makefile {
    const std::string& self_exec_dir(void)
    {
        static const std::string dir = compute_self_exec_dir();
        return dir;
    }

    std::string tool_command(const std::string& tool_name)
    {
        const auto& dir = self_exec_dir();
        if (dir.empty())
            return tool_name;
        return dir + "/" + tool_name;
    }
}
