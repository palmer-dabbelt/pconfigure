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
#include <sys/stat.h>
#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <regex>
#include <sstream>
#include <utility>

/* The ppkg-config named by --ppkg-config, or empty when nobody named
 * one.  FIXME: this is a hack, it doesn't fit the regular argument
 * parsing framework. */
static std::string ppkg_config_option = "";

/* A path somebody gave relative to the directory pconfigure was
 * started in, spelled so that it still names the same thing from any
 * other directory.  Backticks run in the directory of the project
 * whose Configfile they're on, which is only the starting directory
 * for the top project of an in-tree build, and every path this run
 * hands one -- a "--ppkg-config", the build tree's .pc directories --
 * was worked out relative to where pconfigure was started.  Absolute
 * paths are already the same everywhere and are left as they are. */
static std::string from_starting_directory(const std::string& path)
{
    if (path.size() == 0 || path[0] == '/')
        return path;

    auto buffer = std::vector<char>(4096);
    while (getcwd(&buffer[0], buffer.size()) == NULL) {
        if (errno != ERANGE) {
            perror("Unable to find the working directory");
            abort();
        }
        buffer.resize(buffer.size() * 2);
    }

    return std::string(&buffer[0]) + "/" + path;
}

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
    /* A name without a '/' in it is for $PATH to find, wherever the
     * backtick happens to run; one with a '/' is a path, and is rooted
     * where it was typed rather than where the backtick runs, so that
     * "--ppkg-config tools/ppkg-config" names the same program for a
     * subproject's backticks as for the top project's. */
    if (ppkg_config_option.empty() == false) {
        if (ppkg_config_option.find('/') == std::string::npos)
            return ppkg_config_option;
        return from_starting_directory(ppkg_config_option);
    }

    auto sibling = makefile::tool_path("ppkg-config");
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

/* The names CONFIG_DEPS lines gave, which are on the list above too
 * and are kept apart here for the bootstrapped project that did not
 * ask for AUTORECONFIGURE.  Such a project watches no Configfile --
 * running pconfigure again is something a person asks for -- but a
 * CONFIG_DEPS line is a project saying out loud that its Makefile is
 * written out of this path, and the recipe in its committed Makefile
 * can act on that. */
static std::vector<std::string> config_deps;

const std::vector<std::string>& config_deps_named(void)
{
    return config_deps;
}

void add_config_dep(const std::string& path)
{
    add_configfile_dep(path);

    auto normalized = file_utils::normalize_path(path);
    for (const auto& already: config_deps)
        if (already == normalized)
            return;
    config_deps.push_back(normalized);
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

static std::string execute(std::string line, const debug_info::ptr& where,
                           const std::string& directory);
static std::string replace_word(const std::string& haystack,
                                const std::string& word,
                                const std::string& replacement);
static command::ptr parse_written(const debug_info::ptr& where,
                                  const std::string& directory,
                                  bool& said_nothing,
                                  std::string& shown);

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
     * an option the next run gets to read for itself.
     *
     * The one exception is --debug, which is about this run of
     * pconfigure rather than about the build, and which the manual
     * promises leaves the Makefile as it would have been without it.
     * Kept, it became the Makefile's default PCONFIGURE_ARGS, and
     * every reconfigure after it -- the ones AUTORECONFIGURE starts
     * from inside somebody's build included -- printed the debugging
     * dump.  It's dropped below, where the words are walked one option
     * at a time, rather than here: a "--debug" that is the argument
     * to another option is a path or a name, and has to be kept. */
    command_line.clear();

    /* Where in "out" each Configfile line goes, and which word it was. */
    std::vector<std::pair<size_t, int>> lines;

    for (auto i = 1; i < argc; ++i) {
        /* The words from "first" to wherever "i" has got to once this
         * option is parsed are the option and its argument, if it
         * takes one. */
        auto first = i;
        auto record = [&](void) {
            if (strcmp(argv[first], "--debug") == 0)
                return;
            command_line.insert(command_line.end(),
                                argv + first, argv + i + 1);
        };

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
            record();
            continue;
        }

        auto debug = debug_info::command_line(i, argv[i]);

        /* A word that is one of the options is matched exactly as it
         * was typed, and so is the word an option takes after it:
         * that's a name -- a path, a suffix, a version -- and nothing
         * about it is the Configfile syntax the tidying below is for.
         * Tidying the option itself first is no better, since a
         * ' --srcpath' made into --srcpath that way would come too
         * late to be given the word after it. */
        auto option = command::parse_option(argv[i], debug);
        if (option != NULL) {
            auto ecmd = option->consume_extra_arguments(i, argc, argv);
            if (ecmd == NULL) {
                /* The test above is about "option" and this one is
                 * about "ecmd": written the other way it was the same
                 * question asked twice, and the answer to the one
                 * nobody asked was a read off the end of argv. */
                std::cerr << "Command-line option '"
                          << argv[i]
                          << "' needs an argument after it\n";

                abort();
            }

            record();
            out.push_back(ecmd);
            continue;
        }

        /* Anything else is a Configfile line, and is read the way one
         * out of a file is: tidied, and with its backticks run while
         * configuring.  Read as it was typed instead, a run of spaces
         * left an empty word where the operator goes, a space at
         * either end was an empty command name or the end of a value,
         * and backticks went into the Makefile for every compile to
         * run again, with nobody stopping when one failed.
         *
         * Not yet, though.  Backticks run whatever --ppkg-config names,
         * and that option can come after the line: the manual's word
         * is that a line here does what it would at the top of the
         * first file read, and by then every option has been read.
         * So the line keeps its place and is read once they all have
         * been. */
        record();
        lines.push_back(std::make_pair(out.size(), i));
        out.push_back(NULL);
    }

    /* The refusal for a word that is neither an option nor a line
     * that can be read. */
    auto refuse = [&](int i) {
        /* Counted the way the debug_info above counts it, from the
         * first word after the program's name, so that this and every
         * other complaint about the command line ("args:1 '--strict'")
         * give the same word the same number.  The word is quoted as
         * it was typed, since that's what will be looked for in the
         * command that ran this.
         *
         * A word that isn't one of the options is read as a Configfile
         * line, which is why both are named: somebody who mistyped an
         * option wants the list of options, and somebody who meant a
         * line wants to know how one is written. */
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
    };

    /* "--help" and "--version" are answered without configuring
     * anything, and reading a line is configuring: its backticks are
     * commands, run for whatever they leave behind as much as for
     * what they print, and a line that can't be read stops the run.
     * Neither is anything somebody asking for the option list or the
     * version number asked for -- and the likeliest way to be asking
     * is to have added "--help" to the end of a command that just
     * failed, lines and all.  So the lines are left unread.
     *
     * Except for a word that starts with a dash, which no Configfile
     * command does: that is an option somebody got wrong, and it is
     * still refused by name, since an answer that doesn't point at it
     * leaves them hunting for the one word that's the problem.  It is
     * refused without being read as a line, so that even backticks in
     * it go unrun. */
    auto answering = std::any_of(out.begin(), out.end(),
        [](const command::ptr& cmd) {
            return cmd != NULL
                && (cmd->type() == command_type::HELP
                    || cmd->type() == command_type::VERSION);
        });

    for (const auto& line: lines) {
        auto i = line.second;
        auto debug = debug_info::command_line(i, argv[i]);

        if (answering) {
            auto text = string_utils::clean_white(argv[i]);
            if (text.size() > 0 && text[0] == '-')
                refuse(i);
            continue;
        }

        /* What would be an option once its spaces were gone was not
         * typed as one, and is turned away the same way as any other
         * word that isn't an option or a line: taking it as the option
         * would mean an option that never got the word it takes. */
        auto said_nothing = true;
        auto shown = std::string();
        /* A line given here has no Configfile behind it: it was typed
         * into a shell in the directory pconfigure was started in, so
         * that's where its backticks run. */
        auto cmd = parse_written(debug, ".", said_nothing, shown);
        if (cmd != NULL && command::parse_option(shown, debug) != NULL)
            cmd = NULL;

        /* A word that says nothing -- empty, all space, a comment, or
         * a command in backticks that printed nothing -- is what a
         * Configfile line saying nothing is, which is nothing to do. */
        if (said_nothing)
            continue;

        if (cmd == NULL)
            refuse(i);

        out[line.first] = cmd;
    }

    /* The places kept for lines that turned out to say nothing. */
    out.erase(std::remove(out.begin(), out.end(), nullptr), out.end());

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
     * file which is there but can't be read is still found by
     * lines_from_file(), which complains about it with the reason it
     * couldn't be read. */
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
        auto lines = lines_from_file(srcpath, filename, config->debug());
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

/* Reading a line, whether it came out of a Configfile or was given on
 * the command line: the two are meant to be the same thing, and the
 * manual says a line on the command line does exactly what it would at
 * the top of the first file read.  "where" says where the line came
 * from and carries it as it was written.
 *
 * NULL comes back both for a line that says nothing and for one that
 * can't be read, and "said_nothing" tells the two apart, because only
 * the caller knows how to say where an unreadable line was.  "shown"
 * is the line the way any complaint about it should quote it. */
static command::ptr parse_written(const debug_info::ptr& where,
                                  const std::string& directory,
                                  bool& said_nothing,
                                  std::string& shown)
{
    said_nothing = true;
    auto text = string_utils::clean_white(where->line());
    shown = text;

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
    text = string_utils::clean_white(execute(text, where->with_line(typed),
                                             directory));

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
    shown = printed_nothing ? typed : text;
    said_nothing = false;

    return command::parse(text, where->with_line(shown), printed_nothing);
}

command::ptr parse_line(const configfile_line& line)
{
    auto where = std::make_shared<debug_info>(line.filename,
                                              line.number,
                                              line.text);

    auto said_nothing = true;
    auto shown = std::string();
    auto cmd = parse_written(where, line.directory, said_nothing, shown);
    if (said_nothing)
        return NULL;
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
                                             const std::string& filename,
                                             const debug_info::ptr& asked_by)
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

    /* A name with nothing behind it is a Configfile this project
     * simply doesn't use -- nobody has to write a Configfile.local --
     * so it is read as no lines.  Anything else that is there is a
     * file somebody put there to be read, and failing to read it is
     * not the same answer: it used to come out as no lines too, and
     * pconfigure carried on and wrote a Makefile missing everything
     * the file declared, with nothing said about why.  The complaint
     * names the file, and the line that asked for it when there was
     * one -- a CONFIG, or the --config on the command line. */
    auto refuse = [&](const std::string& what,
                      const std::string& why,
                      const std::string& instead)
        {
            if (asked_by != NULL)
                std::cerr << std::to_string(asked_by) << "\n"
                          << "  error: " << filename << " " << what << "\n";
            else
                std::cerr << filename << "\n"
                          << "  error: this Configfile " << what << "\n";
            std::cerr << "  " << why << "\n"
                      << "  " << instead << "\n";
            abort();
        };

    struct stat st;
    if (stat(filename.c_str(), &st) != 0) {
        if (errno == ENOENT || errno == ENOTDIR)
            return out;

        refuse("can't be looked at: " + std::string(strerror(errno)),
               "a Configfile that is there but can't be read would be"
               " read as one with nothing in it",
               "fix the permissions on the directories leading to it,"
               " or remove it if it isn't meant to be part of the build");
    }

    /* A directory passes the executable test every directory passes,
     * so this has to be asked first: otherwise the shell is asked to
     * run it, says "Is a directory", and the lines that were meant
     * one level down go unread. */
    if (S_ISDIR(st.st_mode))
        refuse("is a directory",
               "a Configfile is a file of lines, or a program that prints"
               " them, and a directory is neither",
               "move the lines into a file with this name, or rename the"
               " directory so it doesn't take the Configfile's name");

    /* An executable Configfile is a program that prints one, and it
     * gets run from the directory it lives in: a project's generator
     * only knows about its own tree, and this repository's own
     * Configfiles start by cd'ing into "src".
     *
     * The backticks on the lines of a plain Configfile run there too,
     * since they are the same kind of thing -- a command the project
     * wrote about its own tree -- and a project is supposed to
     * configure the same way on its own as it does pulled into a
     * parent with SUBPROJECTS, or from a build directory with
     * --srcpath.  Run where pconfigure was started instead, a
     * "`cat version`" that worked in the checkout found nothing as
     * soon as it was configured from anywhere else.
     *
     * pconfigure itself deliberately stays where it was started,
     * since every path it has worked out is relative to there. */
    auto directory = srcpath;
    auto script = filename;
    if (filename.compare(0, srcpath.size() + 1, srcpath + "/") == 0)
        script = filename.substr(srcpath.size() + 1);
    else
        directory = ".";

    auto executable = access(filename.c_str(), X_OK) == 0;
    FILE *file = NULL;
    if (executable == true) {

        /* Both halves are one word each to the shell, whatever is in
         * them.  A Configfile's name has no reason to avoid a space or
         * an apostrophe, nor the --srcpath it sits under an apostrophe
         * (whitespace there is refused long before this), and each is
         * fine as a path everywhere else.  Pasted in as they were, a
         * CONFIG called "my conf" ran "./Configfiles/my" with "conf"
         * as its argument and an apostrophe in either half was an
         * unterminated quote -- and every one of those read the same
         * as a program that printed nothing. */
        auto command = "cd " + string_utils::quoted(directory)
                       + " && exec ./" + string_utils::quoted(script);

        /* popen() only fails when no shell could be started at all,
         * which says nothing about the program itself.  The one thing
         * that can be changed from here is not needing a shell: a
         * Configfile that was never meant to be a program reads fine
         * once its executable bit is gone. */
        file = popen(command.c_str(), "r");
        if (file == NULL)
            refuse("is executable, but no shell could be started to run"
                   " it: " + std::string(strerror(errno)),
                   "an executable Configfile is a program, and what it"
                   " prints is what gets read",
                   "if it is a plain Configfile, clear its executable bit"
                   " (chmod a-x) so it is read directly; otherwise free up"
                   " processes or memory and run pconfigure again");
    } else {
        file = fopen(filename.c_str(), "r");
        if (file == NULL)
            refuse("can't be read: " + std::string(strerror(errno)),
                   "a Configfile that is there but can't be read would be"
                   " read as one with nothing in it",
                   "fix the permissions on it (chmod a+r), or remove it if"
                   " it isn't meant to be part of the build");
    }

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
     * in, and those still get refused on the line they're on.
     *
     * That refusal has to happen here, while the line is still every
     * byte that was read.  Left for the parser, a mark at the front of
     * a command's name happened to fail as an unknown command, but one
     * at the front of a value went straight through: "BINARIES +=
     * <mark>main" built a program whose name only looked like "main".
     * A NUL is worse, because everything after this point treats the
     * line as a C string: the rest of the line after one vanished
     * without a word, and a line starting with one -- every line of a
     * UTF-16 file has that shape -- read as a blank line.  Neither is
     * ever part of a line anybody meant to write, so a line with
     * either in it is refused outright, from a file or from what an
     * executable Configfile printed alike. */
    static const std::string byte_order_mark = "\xEF\xBB\xBF";
    for (auto ln: file_utils::readlines_and_numbers(file)) {
        if (ln.number == 1
            && ln.line.compare(0, byte_order_mark.size(), byte_order_mark) == 0)
            ln.line = ln.line.substr(byte_order_mark.size());

        auto nul = ln.line.find('\0');
        auto mark = ln.line.find(byte_order_mark);
        if (nul != std::string::npos || mark != std::string::npos) {
            /* The line itself isn't quoted, since the whole trouble
             * is bytes that don't show up when printed; the column
             * (counted in bytes, from 1) is what says where they are. */
            auto bad = (nul != std::string::npos) ? nul : mark;
            auto what = (nul != std::string::npos)
                ? std::string("a NUL byte")
                : std::string("a UTF-8 byte order mark (EF BB BF)");
            std::cerr << filename << ":" << ln.number << "\n"
                      << "  error: this line has " << what
                      << " in it, at byte " << (bad + 1) << "\n"
                      << "  it doesn't show up on a terminal, but it is"
                      << " part of the line, and a Configfile line is"
                      << " plain text\n";
            if (nul != std::string::npos)
                std::cerr << "  save the file as UTF-8 or ASCII rather"
                          << " than UTF-16, or remove the byte"
                          << (executable ? " from what the program prints" : "")
                          << "\n";
            else
                std::cerr << "  delete the invisible character; a byte"
                          << " order mark is only allowed as the very"
                          << " first thing in the file\n";
            abort();
        }

        out.push_back(configfile_line(filename, ln.number, ln.line,
                                      directory));
    }

    /* The program's exit status isn't looked at.  Executable
     * Configfiles in use today probe the machine they run on and are
     * allowed to fail where a probe doesn't apply, printing nothing
     * and relying on that nothing being read, so refusing a program
     * that exits non-zero needs those fixed first. */
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
std::string execute(std::string line, const debug_info::ptr& where,
                    const std::string& directory)
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
            auto command_str = replace_word(command.str(), "ppkg-config",
                                            string_utils::quoted(ppkg_config_command()));

            bool restore_pkg_config_path = false;
            std::unique_ptr<std::string> saved_pkg_config_path;

            /* A pkg-config that this build produces itself comes
             * first, so that a project linking against a subproject
             * is told where that subproject's build output is rather
             * than where some older copy got installed. */
            if (pkgconfig_path.size() > 0
                && command_str.find("pkg-config") != std::string::npos) {
                /* Each directory is spelled from the directory
                 * pconfigure was started in, which is not where the
                 * command runs for a subproject or a --srcpath build:
                 * there a relative one named a directory under the
                 * project's own tree that doesn't exist, and a package
                 * a sibling subproject provides came back missing. */
                auto path = std::string();
                for (const auto& dir: pkgconfig_path)
                    path += from_starting_directory(dir) + ":";

                /* The directories go into the environment the shell
                 * is started with, rather than in front of the
                 * command as a "PKG_CONFIG_PATH=... " assignment.  An
                 * assignment in front of a command only reaches the
                 * first simple command on the line, so in "ppkg-config
                 * foo-ng --cflags || ppkg-config foo --cflags", or two
                 * questions separated by a ';', everything after the
                 * first one was asked about the machine alone, and a
                 * package this very build provides came back missing.
                 * In front of an 'if' or a '(' it wasn't even shell:
                 * the 'if' got read as the name of a program and the
                 * line was a syntax error.  The environment reaches
                 * every command the shell runs, however the line is
                 * put together, and needs no quoting because it never
                 * passes through the shell's parser at all.
                 *
                 * The caller's own $PKG_CONFIG_PATH goes after this
                 * build's directories, the way it always has, and is
                 * put back once the command is done so that nothing
                 * else this run starts sees the build tree's. */
                const char *caller = getenv("PKG_CONFIG_PATH");
                if (caller != NULL)
                    saved_pkg_config_path.reset(new std::string(caller));
                restore_pkg_config_path = true;
                path += (caller != NULL) ? caller : "";
                if (setenv("PKG_CONFIG_PATH", path.c_str(), 1) != 0) {
                    std::cerr << std::to_string(where) << "\n"
                              << "  error: the command in backticks, '"
                              << command.str() << "', could not be told"
                              << " where this build's .pc files are: "
                              << strerror(errno) << "\n";
                    abort();
                }

                /* This command gets its answer out of the build tree,
                 * which makes the .pc files in it inputs to the
                 * expansion they feed: their contents end up in the
                 * makefile as text, and nothing else in the build
                 * reads them first.  Written down before the command
                 * runs, the same way a Configfile is written down
                 * before it is opened -- which is also why this does
                 * not try to guess which .pc the command will actually
                 * name. */
                for (const auto& dep: pkgconfig_deps)
                    add_configfile_dep(dep);
            }

            /* The command is run from the directory of the project
             * whose line it is on: see lines_from_file().  The 'cd' is
             * a line of its own in front of the command rather than
             * joined to it with a '&&', which would bind only to the
             * first of the commands in "a || b" and leave "b" to run
             * wherever a failed 'cd' left the shell; a failed one
             * here ends the shell, and is a failing command like any
             * other.  CDPATH has been taken out of the environment
             * already, so a relative 'cd' goes where it says. */
            if (directory != ".")
                command_str = "cd " + string_utils::quoted(directory)
                              + " || exit\n" + command_str;

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
             * typed rather than with ppkg-config's path spliced
             * in, since that is what the person will go looking
             * for. */
            auto status = pclose(f);
            if (restore_pkg_config_path == true) {
                if (saved_pkg_config_path)
                    setenv("PKG_CONFIG_PATH", saved_pkg_config_path->c_str(), 1);
                else
                    unsetenv("PKG_CONFIG_PATH");
            }
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

/* Whether "c" ends a shell word on either side of it: blanks, and the
 * operators that start a new command without needing a blank -- a
 * pipe, a ';', a '&&', a '<' or '>', and the parentheses of a '$(' or
 * a subshell. */
static bool ends_shell_word(char c)
{
    return isspace((unsigned char)c) || strchr("|;&()<>", c) != NULL;
}

/* Replaces "word" in "haystack" only where it stands as a word of its
 * own, which is all the Configfile ever meant by writing it.  Replacing
 * every occurrence also rewrote text that merely contains it: a
 * ppkg-config named by its path ("/opt/x/bin/ppkg-config") became
 * that directory followed by a second, quoted absolute path, a
 * project's own "tools/ppkg-config-shim" became "tools/" glued to one,
 * and a value like "myppkg-config" that was only being echoed came out
 * altered.  The first two named nothing and stopped the configure; the
 * last went into the build quietly wrong.
 *
 * A '/' is deliberately not a boundary: a path whose last component is
 * the word already says which program it means, and that's the one
 * that should run.  Quotes aren't boundaries either, so that a value
 * the shell is only being asked to print is left as written. */
std::string replace_word(const std::string& haystack,
                         const std::string& word,
                         const std::string& replacement)
{
    auto out = std::string();
    size_t i = 0;
    while (i < haystack.size()) {
        auto at = haystack.find(word, i);
        if (at == std::string::npos)
            break;

        auto end = at + word.size();
        bool starts = at == 0 || ends_shell_word(haystack[at - 1]);
        bool stops = end == haystack.size() || ends_shell_word(haystack[end]);

        out += haystack.substr(i, at - i);
        if (starts && stops) {
            out += replacement;
            i = end;
        } else {
            out += haystack[at];
            i = at + 1;
        }
    }
    out += haystack.substr(i);
    return out;
}
