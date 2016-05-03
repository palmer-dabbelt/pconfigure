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

#include "commands.h++"
#include "debug_info.h++"
#include "file_utils.h++"
#include "string_utils.h++"
#include <unistd.h>
#include <fcntl.h>
#include <cstdlib>
#include <iostream>
#include <sstream>

static std::string execute(std::string line);

std::vector<command::ptr> commands(int argc, const char **argv)
{
    std::vector<command::ptr> out;

    for (auto i = 1; i < argc; ++i) {
        auto debug = std::make_shared<debug_info>("args",
                                                  i,
                                                  argv[i]);

        auto cmd = command::parse(argv[i], debug);
        if (cmd == NULL) {
            std::cerr << "Unable to parse command-line option "
                      << (i - 1)
                      << ": '"
                      << argv[i]
                      << "'\n";

            abort();
        }

        out.push_back(cmd);
    }

    for (const auto& command: commands())
        out.push_back(command);

    return out;
}

std::vector<command::ptr> commands(const std::string& prefix,
                                   const std::string& suffix)
{
    auto filenames = std::vector<std::string>{
        prefix + "s/" + suffix,
        prefix + "." + suffix
    };

    std::vector<command::ptr> out;
    for (const auto& filename: filenames) {
        auto cmds = commands(filename);
        out.insert(out.end(), cmds.begin(), cmds.end());
    }
    return out;
}

std::vector<command::ptr> commands(void)
{
    auto filenames = std::vector<std::string>{
        "Configfiles/local",
        "Configfile.local",
        "Configfiles/main",
        "Configfile"
    };

    std::vector<command::ptr> out;
    for (const auto& filename: filenames) {
        auto cmds = commands(filename);
        out.insert(out.end(), cmds.begin(), cmds.end());
    }
    return out;
}

std::vector<command::ptr> commands(const std::string& filename)
{
    auto out = std::vector<command::ptr>();

    auto file = [&]()
        {
            if (access(filename.c_str(), X_OK) == 0)
                return popen(("./" + filename).c_str(), "r");
            else
                return fopen(filename.c_str(), "r");
        }();
    if (file == NULL)
        return out;

    for (const auto& ln: file_utils::readlines_and_numbers(file)) {
        auto line = execute(string_utils::clean_white(ln.line));

        /* Skip empty lines and anything beginning with a '#' --
         * those are comments. */
        if (line.size() == 0)
            continue;
        if (line[0] == '#')
            continue;

        auto linenum = ln.number;

        auto debug = std::make_shared<debug_info>(filename,
                                                  linenum,
                                                  line);

        auto cmd = command::parse(line, debug);
        if (cmd == NULL) {
            std::cerr << "Unable to parse "
                      << filename
                      << ":"
                      << linenum
                      << ": '"
                      << line
                      << "'\n";

            abort();
        }

        out.push_back(cmd);
    }

    if (access(filename.c_str(), X_OK) == 0)
        pclose(file);
    else
        fclose(file);

    return out;
}

std::string execute(std::string line)
{
    if (line.find('`') == std::string::npos)
        return line;

    std::ostringstream executed;
    std::ostringstream command;
    bool in_command = false;
    for (const auto& c: line) {
        if (in_command == true && c == '`') {
            auto f = popen(command.str().c_str(), "r");
            for (const auto& l: file_utils::readlines(f))
                executed << string_utils::clean_white(l);
            pclose(f);
        } else if (in_command == true) {
            command << c;
        } else if (c == '`') {
            in_command = true;
            command.str("");
            command.clear(); 
        } else {
            executed << c;
        }
    }

    return executed.str();
}

