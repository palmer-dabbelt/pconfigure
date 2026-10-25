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
#include <libmakefile/self_path.h++>
#include <unistd.h>
#include <fcntl.h>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <regex>
#include <sstream>

/* The ppkg-config named by --ppkg-config, or empty when nobody named
 * one.  FIXME: this is a hack, it doesn't fit the regular argument
 * parsing framework. */
static std::string ppkg_config_option = "";

/* How a backtick is told to say "ppkg-config".
 *
 * Not the bare name: that leaves the answer to $PATH, which is a
 * question about the machine rather than about this build.  A tree
 * that vendors pconfigure and runs it out of src/pconfigure/bin has
 * the matching ppkg-config sitting right beside it and no reason to
 * have installed one, so the bare name sent it looking for a copy that
 * need not exist -- and getting it wrong is quiet: the shell writes
 * "ppkg-config: command not found" and the backtick expands to
 * nothing, so a LINKOPTS line that asked about a package comes out as
 * though it had asked about nothing at all.  Resolved beside the
 * running pconfigure instead, which is where every other helper tool
 * is named from (makefile::tool_command) and for the same reason: the
 * tool that matches the pconfigure doing the configuring is the one
 * that should answer.
 *
 * $PATH still answers when there is no sibling to run, because a
 * layout that keeps pconfigure apart from its tools is exactly the
 * case $PATH was covering. */
static std::string ppkg_config_command(void)
{
    if (ppkg_config_option.empty() == false)
        return ppkg_config_option;

    auto sibling = makefile::tool_command("ppkg-config");
    if (sibling != "ppkg-config" && access(sibling.c_str(), X_OK) == 0)
        return sibling;

    return "ppkg-config";
}

/* The pkg-config files this run knows how to build.  There's one list
 * for the whole run rather than one per project on purpose: which
 * packages exist is a property of the build, not of whoever happens
 * to be asking about them. */
static std::vector<std::string> pkgconfig_path;

/* Every file this run went looking for a Configfile line in, in the
 * order it looked.  One list for the whole run rather than one per
 * project, for the same reason as the one above: a project's
 * Configfile is read by whoever is configuring the tree, and the
 * question "what was this build written out of" has one answer.
 *
 * The names of files that were not there are on it too.  Which of
 * them existed is a fact about the moment of configuring, and a build
 * that wants to know when the answer changes has to be told about the
 * ones that could appear as well as the ones that did. */
static std::vector<std::string> configfiles;

const std::vector<std::string>& configfiles_read(void)
{
    return configfiles;
}

void add_configfile_dep(const std::string& path)
{
    /* The same de-duplication lines_from_file does, and for the same
     * reason: two families of tests in one directory would otherwise
     * name it twice, and a prerequisite list is a set. */
    auto normalized = file_utils::normalize_path(path);
    for (const auto& already: configfiles)
        if (already == normalized)
            return;
    configfiles.push_back(normalized);
}

void add_pkgconfig_path(const std::string& dir)
{
    for (const auto& existing: pkgconfig_path)
        if (existing == dir)
            return;

    pkgconfig_path.push_back(dir);
}

/* The built copies of the pkg-config files this run writes: one per
 * pkgconfig LIBRARY, spelled the way the Makefile names them.  These
 * are inputs to the backtick expansion below -- a Configfile that
 * asks ppkg-config about a package is answered out of one of these --
 * and the answer is written into the generated makefile as literal
 * text, so a built .pc that changes later is a change to what the
 * configure step said, not to anything make was watching.  They go on
 * the watched list at expansion time, so that a build that never
 * asked about the package doesn't watch it either. */
static std::vector<std::string> pkgconfig_deps;

void add_pkgconfig_dep(const std::string& path)
{
    /* The same de-duplication add_configfile_dep() does, and for the
     * same reason: a prerequisite list is a set. */
    auto normalized = file_utils::normalize_path(path);
    for (const auto& already: pkgconfig_deps)
        if (already == normalized)
            return;
    pkgconfig_deps.push_back(normalized);
}

static std::string execute(std::string line, const debug_info::ptr& where);
static std::string replace_all(std::string haystack, std::string needle, std::string new_needle);

static std::vector<std::string> command_line;

const std::vector<std::string>& command_line_read(void)
{
    return command_line;
}

std::vector<command::ptr> commands(int argc, const char **argv)
{
    std::vector<command::ptr> out;

    /* Every word, kept exactly as it was typed rather than as it was
     * understood, because what it is kept for is running pconfigure
     * again: the words that mean the same thing tomorrow are the ones
     * that were given today, and an option this run read one way is
     * an option the next run gets to read for itself. */
    command_line.assign(argv + 1, argv + argc);

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

            ppkg_config_option = argv[i+1];
            ++i;
            continue;
        }

        auto debug = debug_info::command_line(i, argv[i]);

        auto cmd = command::parse(argv[i], debug);
        if (cmd == NULL) {
            /* Counted the way the debug_info above counts it, from
             * the first word after the program's name, so that this
             * and every other complaint about the command line ("args:1
             * '--strict'") give the same word the same number.
             *
             * A word that isn't one of the options is read as a
             * Configfile line, which is why both are named: somebody
             * who mistyped an option wants the list of options, and
             * somebody who meant a line wants to know how one is
             * written. */
            std::cerr << "Unable to parse command-line option "
                      << i
                      << ": '"
                      << argv[i]
                      << "'\n"
                      << "  it isn't one of the options"
                      << " 'pconfigure --help' lists, and a word that"
                      << " isn't an option is read as a Configfile line,"
                      << " which goes in as one quoted word: pconfigure 'LANGUAGES += c'\n";

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
                                          const command::ptr& config)
{
    const auto& suffix = config->data();
    auto filenames = std::vector<std::string>{
        srcpath + "/Configfiles/" + suffix,
        srcpath + "/Configfile." + suffix
    };

    /* Either file on its own is enough, which is what lets a tree keep
     * a configuration in whichever of the two places suits it.  Having
     * neither is a different matter: lines_from_file() reads a file
     * that isn't there as one with no lines in it, which is the right
     * answer for the default Configfiles -- nobody has to write a
     * Configfile.local -- and the wrong one here.  A CONFIG is a line
     * somebody wrote to pull something into the build, and a
     * misspelled one used to pull in nothing at all while pconfigure
     * carried on and wrote a Makefile that was quietly missing
     * everything the file would have declared.
     *
     * Existence is the question rather than readability, so that a
     * file which is there but can't be read is still found by whatever
     * reads it, and complained about there if it is going to be. */
    auto found = false;
    for (const auto& filename: filenames)
        if (access(filename.c_str(), F_OK) == 0)
            found = true;
    if (found == false) {
        std::cerr << std::to_string(config->debug()) << "\n"
                  << "  error: CONFIG names '" << suffix
                  << "', but neither " << filenames[0]
                  << " nor " << filenames[1] << " exists\n"
                  << "  a CONFIG reads the Configfile with that suffix,"
                  << " and with no file there it would read nothing at"
                  << " all\n"
                  << "  write the name of a Configfile that is there, or"
                  << " create one of those two files\n";
        abort();
    }

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

    /* What the backticks printed -- or didn't -- is part of the line
     * now, so the line is tidied again and read the same way as one
     * somebody typed out.  A command that printed nothing otherwise
     * leaves the gaps either side of it behind as two spaces, and
     * "SOURCES += `true` main.c" names a source called " main.c". */
    auto typed = text;
    auto where = std::make_shared<debug_info>(line.filename,
                                              line.number,
                                              typed);
    text = string_utils::clean_white(execute(text, where));

    /* A line that was nothing but a command which printed nothing is
     * a line with nothing left in it. */
    if (text.size() == 0)
        return NULL;

    /* A line whose command and operator were written out, but whose
     * whole value came from backticks that printed nothing, is not
     * the same line as one typed without a value, and isn't refused
     * as unfinished here: adding nothing to a list of options is a
     * legal thing for a command to ask for, and the usual answer from
     * "pkg-config --cflags" for a library the compiler already finds.
     * Which commands can be given nothing is for the command processor
     * to say, once the command itself has been checked.
     *
     * Everything said about such a line quotes it as it was written:
     * what it expanded to has no value in it, and pointing at a line
     * nobody typed would send them looking for the wrong mistake. */
    auto words = string_utils::split_char(text, " ");
    auto typed_words = string_utils::split_char(typed, " ");
    auto printed_nothing = (words.size() == 2)
        && (typed_words.size() > 2)
        && (typed_words[0] == words[0])
        && (typed_words[1] == words[1]);
    auto shown = printed_nothing ? typed : text;

    auto debug = std::make_shared<debug_info>(line.filename,
                                              line.number,
                                              shown);

    auto cmd = command::parse(text, debug, printed_nothing);
    if (cmd == NULL) {
        std::cerr << "Unable to parse "
                  << line.filename
                  << ":"
                  << line.number
                  << ": '"
                  << shown
                  << "'\n";

        abort();
    }

    return cmd;
}

std::vector<configfile_line> lines_from_file(const std::string& srcpath,
                                             const std::string& filename)
{
    auto out = std::vector<configfile_line>();

    /* Written down before anything is opened, so that a name nobody
     * could read is still a name this run asked about. */
    {
        auto normalized = file_utils::normalize_path(filename);
        auto seen = false;
        for (const auto& already: configfiles)
            if (already == normalized)
                seen = true;
        if (seen == false)
            configfiles.push_back(normalized);
    }

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
     * only becomes a command when it's about to be processed.
     *
     * The one exception is a UTF-8 byte order mark at the very start
     * of the file, which plenty of Windows editors write without
     * being asked.  It describes the file's encoding rather than being
     * part of its text, and left in place it became the first three
     * bytes of the first command's name -- so the complaint was about
     * an unknown command that looked exactly like LANGUAGES on a
     * terminal.  Only the start of the file is forgiven: the same
     * bytes anywhere else are an invisible character somebody pasted
     * in, and those still get refused on the line they're on. */
    static const std::string byte_order_mark = "\xEF\xBB\xBF";
    for (auto ln: file_utils::readlines_and_numbers(file)) {
        if (ln.number == 1
            && ln.line.compare(0, byte_order_mark.size(), byte_order_mark) == 0)
            ln.line = ln.line.substr(byte_order_mark.size());
        out.push_back(configfile_line(filename, ln.number, ln.line));
    }

    if (executable == true)
        pclose(file);
    else
        fclose(file);

    return out;
}

/* "where" is the line as it was written, for the errors: a command
 * that can't be run is a mistake on a particular Configfile line, and
 * the text of that line on its own is no help finding it in a tree
 * with a Configfile, a Configfiles/main and a handful of CONFIGs. */
std::string execute(std::string line, const debug_info::ptr& where)
{
    if (line.find('`') == std::string::npos)
        return line;

    std::ostringstream executed;
    std::ostringstream command;
    bool in_command = false;
    for (const auto& c: line) {
        if (in_command == true && c == '`') {
            /* The ppkg-config goes in as one quoted word, because
             * it is a path and the text around it is about to be
             * handed to a shell.  The Configfile only ever wrote the
             * one word "ppkg-config"; whatever directory the answer
             * lives in is a fact about where the tools were put,
             * which is nothing the Configfile could have quoted for.
             * Pasted in bare, a pconfigure installed under "my
             * tools/bin" -- or a "--ppkg-config" naming one there --
             * had the shell run "/x/my" instead, the backtick expand
             * to nothing, and the consumer configured quietly
             * without the flags it asked for. */
            auto command_str = replace_all(command.str(), "ppkg-config",
                                           string_utils::quoted(ppkg_config_command()));

            /* A pkg-config that this build produces itself comes
             * first, so that a project linking against a subproject
             * is told where that subproject's build output is rather
             * than where some older copy got installed. */
            if (pkgconfig_path.size() > 0
                && command_str.find("pkg-config") != std::string::npos) {
                auto path = std::string();
                for (const auto& dir: pkgconfig_path)
                    path += dir + ":";

                /* Quoted for the same reason as the ppkg-config
                 * above: these directories are paths, not shell.  The
                 * caller's own $PKG_CONFIG_PATH stays outside the
                 * quotes so that it is still expanded, and needs none
                 * of its own because the right-hand side of an
                 * assignment is never split into words. */
                command_str = "PKG_CONFIG_PATH=" + string_utils::quoted(path)
                              + "$PKG_CONFIG_PATH "
                              + command_str;

                /* The PKG_CONFIG_PATH above says this command gets its
                 * answer out of the build tree, which makes the .pc
                 * files in it inputs to the expansion they feed: their
                 * contents end up in the makefile as text, and nothing
                 * else in the build reads them first.  Written down
                 * before the command runs, the same way a Configfile
                 * is written down before it is opened -- which is also
                 * why this does not try to guess which .pc the command
                 * will actually name. */
                for (const auto& dep: pkgconfig_deps)
                    add_configfile_dep(dep);
            }

            /* What the command printed goes in the way a shell's
             * command substitution would put it there: a line break
             * is only the space between two words, the same as any
             * other run of white space, and all of it collapses to a
             * single space.  Cleaning each line on its own and gluing
             * the results end to end is how a pkg-config that prints
             * one flag per line turned "-DA" and "-DB" into "-DA-DB",
             * and "-lm" and "-lc" into a library called "m-lc".  The
             * output is put back together whole, line breaks and all,
             * before it's cleaned, so the breaks are there to be
             * turned into spaces like any other white space. */
            auto f = popen(command_str.c_str(), "r");
            if (f == NULL) {
                std::cerr << std::to_string(where) << "\n"
                          << "  error: the command in backticks, '"
                          << command.str() << "', could not be started: "
                          << strerror(errno) << "\n";
                abort();
            }
            std::string output;
            for (const auto& l: file_utils::readlines(f))
                output += l;
            executed << string_utils::clean_white(output);

            /* A command that fails stops the run.  This is how a
             * Configfile asks whether a package is installed --
             * "pkg-config --cflags foo" exits non-zero and prints
             * nothing on stdout when foo isn't there -- and carrying
             * on used to write a Makefile with that line's flags
             * quietly missing, so the person found out at compile
             * time from a missing header with nothing pointing back
             * here.  A required dependency that isn't there is the
             * one thing configuring is for finding out.
             *
             * The command's own stderr has already been passed
             * through, so this says which line ran it and how it
             * ended -- as an exit status, not the wait status pclose()
             * returns, which shifts the code left by eight and turns
             * "exit 1" into "256".  The command is quoted as it was
             * typed rather than with ppkg-config's path and
             * PKG_CONFIG_PATH spliced in, since that is what the
             * person will go looking for. */
            auto status = pclose(f);
            if (status != 0) {
                std::cerr << std::to_string(where) << "\n"
                          << "  error: the command in backticks, '"
                          << command.str() << "', "
                          << file_utils::describe_wait_status(status) << "\n"
                          << "  a failing command stops configuring, rather"
                          << " than leaving this line without what it"
                          << " would have printed\n"
                          << "  if it is allowed to fail, say so in the"
                          << " command: pass --optional to ppkg-config, or"
                          << " end it with '|| true'\n";
                abort();
            }

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
        std::cerr << std::to_string(where) << "\n"
                  << "  error: unterminated '`'\n"
                  << "  everything after a '`' is a command to run until"
                  << " the next '`',\n"
                  << "  so this line has no end for the command in it\n"
                  << "  close the command with a second '`'\n";
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
