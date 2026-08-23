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

/* FIXME: This is a hack, it's used to set the path to ppkg-config */
std::string ppkg_config = "ppkg-config";

/* The pkg-config files this run knows how to build.  There's one list
 * for the whole run rather than one per project on purpose: which
 * packages exist is a property of the build, not of whoever happens
 * to be asking about them. */
static std::vector<std::string> pkgconfig_path;

void add_pkgconfig_path(const std::string& dir)
{
    for (const auto& existing: pkgconfig_path)
        if (existing == dir)
            return;

    pkgconfig_path.push_back(dir);
}

static std::string execute(std::string line);
static std::string replace_all(std::string haystack, std::string needle, std::string new_needle);

std::vector<command::ptr> commands(int argc, const char **argv)
{
    std::vector<command::ptr> out;

    for (auto i = 1; i < argc; ++i) {
        /* FIXME: This doesn't fit into the regular argument parsing framework,
         * so instead I'm just doing this here. */
        if (strcmp(argv[i], "--ppkg-config") == 0) {
            /* Which is why this needs its own copy of the check every
             * other option gets from consume_extra_arguments(): the
             * standard says argv[argc] is a null pointer, so the word
             * after the last one is not a word, and building a string
             * out of it is how this used to die of a signal. */
            if (i + 1 >= argc) {
                std::cerr << "Command-line option '"
                          << argv[i]
                          << "' needs an argument after it\n";

                abort();
            }

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
        if (ecmd == NULL) {
            /* The test above is about "cmd" and this one is about
             * "ecmd": written the other way it was the same question
             * asked twice, and the answer to the one nobody asked was
             * a read off the end of argv. */
            std::cerr << "Command-line option '"
                      << argv[i]
                      << "' needs an argument after it\n";

            abort();
        }

        out.push_back(ecmd);
    }

    return out;
}

std::vector<configfile_line> config_lines(const std::string& srcpath,
                                          const std::string& prefix,
                                          const std::string& suffix)
{
    auto filenames = std::vector<std::string>{
        srcpath + "/" + prefix + "s/" + suffix,
        srcpath + "/" + prefix + "." + suffix
    };

    std::vector<configfile_line> out;
    for (const auto& filename: filenames) {
        auto lines = lines_from_file(srcpath, filename);
        out.insert(out.end(), lines.begin(), lines.end());
    }
    return out;
}

std::vector<configfile_line> configfile_lines(const std::string& srcpath)
{
    auto filenames = std::vector<std::string>{
        srcpath + "/Configfiles/local",
        srcpath + "/Configfile.local",
        srcpath + "/Configfiles/main",
        srcpath + "/Configfile"
    };

    std::vector<configfile_line> out;
    for (const auto& filename: filenames) {
        auto lines = lines_from_file(srcpath, filename);
        out.insert(out.end(), lines.begin(), lines.end());
    }
    return out;
}

command::ptr parse_line(const configfile_line& line)
{
    auto text = string_utils::clean_white(line.text);

    /* Skip empty lines and anything beginning with a '#' --
     * those are comments.  This happens before the backticks in the
     * line get run, because a comment is not a command: a line that
     * has been commented out has been taken out of the build, and
     * running half of it anyway is the one thing nobody meant by
     * putting a '#' in front of it. */
    if (text.size() == 0)
        return NULL;
    if (text[0] == '#')
        return NULL;

    text = execute(text);

    /* A line that was nothing but a command which printed nothing is
     * a line with nothing left in it. */
    if (text.size() == 0)
        return NULL;

    auto debug = std::make_shared<debug_info>(line.filename,
                                              line.number,
                                              text);

    auto cmd = command::parse(text, debug);
    if (cmd == NULL) {
        std::cerr << "Unable to parse "
                  << line.filename
                  << ":"
                  << line.number
                  << ": '"
                  << text
                  << "'\n";

        abort();
    }

    return cmd;
}

std::vector<configfile_line> lines_from_file(const std::string& srcpath,
                                             const std::string& filename)
{
    auto out = std::vector<configfile_line>();

    /* An executable Configfile is a program that prints one, and it
     * gets run from the directory it lives in: a project's generator
     * only knows about its own tree, and this repository's own
     * Configfiles start by cd'ing into "src".
     *
     * pconfigure itself deliberately stays where it was started,
     * since every path it has worked out is relative to there. */
    auto executable = access(filename.c_str(), X_OK) == 0;
    auto file = [&]() -> FILE*
        {
            if (executable == true) {
                auto directory = srcpath;
                auto script = filename;
                if (filename.compare(0, srcpath.size() + 1, srcpath + "/") == 0)
                    script = filename.substr(srcpath.size() + 1);
                else
                    directory = ".";

                return popen(("cd " + directory + " && exec ./" + script).c_str(),
                             "r");
            }

            if (access(filename.c_str(), R_OK) == 0)
                return fopen(filename.c_str(), "r");

            return NULL;
        }();
    if (file == NULL)
        return out;

    /* Nothing is done to the lines here beyond reading them: a line
     * only becomes a command when it's about to be processed. */
    for (const auto& ln: file_utils::readlines_and_numbers(file))
        out.push_back(configfile_line(filename, ln.number, ln.line));

    if (executable == true)
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
            auto command_str = replace_all(command.str(), "ppkg-config", ppkg_config);

            /* A pkg-config that this build produces itself comes
             * first, so that a project linking against a subproject
             * is told where that subproject's build output is rather
             * than where some older copy got installed. */
            if (pkgconfig_path.size() > 0
                && command_str.find("pkg-config") != std::string::npos) {
                auto path = std::string();
                for (const auto& dir: pkgconfig_path)
                    path += dir + ":";

                command_str = "PKG_CONFIG_PATH=" + path + "$PKG_CONFIG_PATH "
                              + command_str;
            }

            auto f = popen(command_str.c_str(), "r");
            for (const auto& l: file_utils::readlines(f))
                executed << string_utils::clean_white(l);
            auto exitcode = pclose(f);
            if (exitcode != 0)
                std::cerr << "'" << command_str << "': " << std::to_string(exitcode) << "\n";

            /* The closing backtick ends the command and nothing else:
             * what comes after it is the rest of the line, which is
             * as much a part of what was written as what came before
             * it was.  Leaving this set is how "-DA=`echo hi`SUFFIX"
             * came out as "-DA=hi" and how a PATH built out of one of
             * these lost everything past the last backtick. */
            in_command = false;
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

    /* A backtick that never closes has swallowed the rest of the
     * line, and there is no way to guess where whoever wrote it meant
     * the command to stop.  Saying so beats running some prefix of
     * the line and dropping the rest without a word, which is what
     * this used to do. */
    if (in_command == true) {
        std::cerr << "unterminated '`' in '" << line << "'\n"
                  << "  everything after a '`' is a command to run until"
                  << " the next '`',\n"
                  << "  so this line has no end for the command in it\n";
        abort();
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
