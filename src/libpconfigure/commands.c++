/*
 * Copyright (C) 2015,2016 Palmer Dabbelt
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
#include <regex>
#include <sstream>

/* FIXME: This is a hack, it's set from command.c++ */
std::string srcpath = ".";

/* FIXME: This is a hack, it's used to set the path to ppkg-config */
std::string ppkg_config = "ppkg-config";

static std::string execute(std::string line);
static std::string replace_all(std::string haystack, std::string needle, std::string new_needle);

std::vector<command::ptr> commands(int argc, const char **argv)
{
    std::vector<command::ptr> out;

    for (auto i = 1; i < argc; ++i) {
        /* FIXME: This doesn't fit into the regular argument parsing framework,
         * so instead I'm just doing this here. */
        if (strcmp(argv[i], "--ppkg-config") == 0) {
            ppkg_config = argv[i+1];
            ++i;
            continue;
        }

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
        auto ecmd = cmd->consume_extra_arguments(i, argc, argv);
        if (cmd == NULL) {
            std::cerr << "Unable to parse extra arguments "
                      << (i - 1)
                      << ": '"
                      << argv[i]
                      << "'\n";

            abort();
        }

        out.push_back(ecmd);
    }

    for (const auto& command: commands())
        out.push_back(command);

    return out;
}

std::vector<command::ptr> commands(const std::string& prefix,
                                   const std::string& suffix)
{
    auto filenames = std::vector<std::string>{
        srcpath + "/" + prefix + "s/" + suffix,
        srcpath + "/" + prefix + "." + suffix
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
        srcpath + "/Configfiles/local",
        srcpath + "/Configfile.local",
        srcpath + "/Configfiles/main",
        srcpath + "/Configfile"
    };

    std::vector<command::ptr> out;
    for (const auto& filename: filenames) {
        auto cmds = commands(filename);
        out.insert(out.end(), cmds.begin(), cmds.end());
    }
    return out;
}

/* Workaround for non GNU systems */
#ifndef _GNU_SOURCE
static char* get_current_dir_name()
{
    size_t bufsz = 1024;
    char *malloced_ptr = (char*) malloc(bufsz);
    while ((getcwd(malloced_ptr, bufsz) == NULL) && errno == ERANGE)
        malloced_ptr = (char*) realloc(malloced_ptr, (bufsz *= 2));
    return malloced_ptr;
}
#endif

std::vector<command::ptr> commands(const std::string& filename)
{
    auto out = std::vector<command::ptr>();
    auto origpwd = [&]()
        {
            auto malloced_ptr = get_current_dir_name();
            auto strout = std::string(malloced_ptr);
            free(malloced_ptr);
            return strout;
        }();

    auto file = [&]()
        {
            if (access(("./" + filename).c_str(), X_OK) == 0)
                return popen(("./" + filename).c_str(), "r");
            if (access(filename.c_str(), X_OK) == 0) {
                if (chdir(srcpath.c_str()) != 0) {
                    perror("Unable to chdir");
                    abort();
                }
                return popen(filename.c_str(), "r");
            }
            if (access(filename.c_str(), R_OK) == 0)
                return fopen(filename.c_str(), "r");

            return (FILE*)NULL;
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

    if (chdir(origpwd.c_str()) != 0) {
        perror("Unable to chdir");
        abort();
    }

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
            auto command_str = replace_all(command.str(), "ppkg-config", ppkg_config);
            auto f = popen(command_str.c_str(), "r");
            for (const auto& l: file_utils::readlines(f))
                executed << string_utils::clean_white(l);
            auto exitcode = pclose(f);
            if (exitcode != 0)
                std::cerr << "'" << command_str << "': " << std::to_string(exitcode) << "\n";
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

std::string replace_all(std::string haystack, std::string needle, std::string new_needle)
{
    /* FIXME: This implementation is afwul, but I'm tired. */
    auto out = std::string("");
    for (size_t i = 0; i < haystack.size(); ++i) {
        if (strncmp(haystack.c_str() + i, needle.c_str(), needle.size()) == 0 ) {
            out = out + new_needle;
            i += needle.size();
            --i;
        } else {
            char s[] = {haystack[i], '\0'};
            out = out + std::string(s);
        }
    }
    return out;
}
