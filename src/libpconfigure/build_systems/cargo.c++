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

#include "cargo.h++"
#include "../file_utils.h++"
#include "../string_utils.h++"
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <iostream>

build_system_cargo::build_system_cargo(const std::string& name)
: build_system(name),
  _cargo("cargo"),
  _profile(),
  _target(),
  _packages(),
  _bins(),
  _features(),
  _all_features(false),
  _no_default_features(false),
  _locked(false),
  _offline(false),
  _jobs(),
  _args(),
  _env(),
  _depends(),
  _install_root()
{
}

build_system* build_system_cargo::clone(void) const
{
    /* Everything a CONFIGUREOPTS puts in here is a string, a bool or
     * a vector of strings, so the copy constructor has already made
     * the deep copy this promises to make.  It stays that way as long
     * as nobody puts a pointer to something shared in the class. */
    return new build_system_cargo(*this);
}

bool build_system_cargo::can_build(const std::string& base) const
{
    /* One file, and one file is enough.  A Cargo.toml is what cargo
     * itself looks for, nothing else in the world is called that, and
     * a crate always has one at the top -- so a directory with one in
     * it is a Rust tree and a directory without one isn't, with no
     * second question to ask.
     *
     * Being this short is only safe because it's this specific.  A
     * bare "Makefile" would be a claim on half the trees in the
     * world; this is a claim on exactly the trees cargo builds. */
    return access((base + "Cargo.toml").c_str(), R_OK) == 0;
}

namespace {
    /* Which of the arguments this build system decides for itself a
     * word on cargo's command line is, said in the one spelling the
     * advice below is written against -- and "" for a word this build
     * system has no opinion about.
     *
     * This is a function rather than a list of names to compare
     * against because cargo's command line has one-letter flags in
     * it, and neither of the two things a one-letter flag does leaves
     * a name for a list of names to find.  A short flag takes its
     * value stuck to the end of the word, so "-m../other/Cargo.toml"
     * is a "--manifest-path" aimed at a crate no SUBPROJECTS named;
     * and several of them cluster into one word, so "-qr" is a
     * "--release" written where nobody would look for it -- which
     * moves the directory every SUBPROJECT_TARGETS in the project is
     * named relative to, quietly, because cargo takes it without a
     * word.
     *
     * A cluster is read the way a shell reads one: left to right,
     * stopping at the first flag that takes a value, since the rest
     * of the word is that value rather than more flags.  That is what
     * keeps a "-prand" -- a "--package rand" said in one word -- from
     * being read as a "--release" on account of the 'r' in the
     * crate's name. */
    std::string reserved_flag(const std::string& word)
    {
        /* The whole-name spellings, which are the ones anybody writes
         * on purpose. */
        if (word == "--manifest-path" || word == "--target-dir"
            || word == "--profile" || word == "--release"
            || word == "--target" || word == "--config"
            || word == "--artifact-dir" || word == "--out-dir")
            return word;

        /* Anything else spelled with two dashes is a whole name as
         * well, and one this build system has nothing to say about.
         * The letters inside it are letters of a name rather than
         * one-letter flags. */
        if (word.compare(0, 2, "--") == 0)
            return "";

        if (word.size() < 2 || word[0] != '-')
            return "";

        for (size_t i = 1; i < word.size(); ++i) {
            switch (word[i]) {
            /* The two that are this build system's, wherever in the
             * cluster they turn up. */
            case 'r':
                return "--release";
            case 'm':
                return "--manifest-path";

            /* And the ones that end a cluster by taking a value:
             * "--package", "--features", "--jobs" and the flag that
             * turns on an unstable feature.  None of those is
             * reserved, and what follows one of them in the word is
             * text somebody wrote rather than more flags. */
            case 'p':
            case 'F':
            case 'j':
            case 'Z':
                return "";
            }
        }

        return "";
    }

    /* What to say when an "--arg" names one of the few cargo
     * arguments this build system has to decide for itself, or "" for
     * an argument it has no opinion about.
     *
     * The ones in here are not a matter of taste.  Two of them decide
     * where cargo writes, which is the difference between a vendored
     * crate that stays out of somebody else's checkout and one that
     * doesn't; three more decide the directory a built program lands
     * in, which is what a SUBPROJECT_TARGETS is named relative to;
     * one copies what was built out of the object directory
     * altogether, under either of the two names cargo has called it;
     * and the last of them says any of those in cargo's own words.
     * Passed through quietly they'd each break something a long way
     * from the line that did it. */
    std::string reserved_advice(const std::string& flag)
    {
        if (flag == "--manifest-path")
            return "the crate this builds is the one the SUBPROJECTS named,"
                   " so there's nothing left for this to point at";

        if (flag == "--target-dir")
            return "cargo's output goes in this subproject's object"
                   " directory, which is what keeps it out of the vendored"
                   " tree";

        if (flag == "--profile" || flag == "--release")
            return "the profile decides which directory cargo writes a"
                   " program into, so write '--profile NAME' or '--release'"
                   " as a CONFIGUREOPTS of its own";

        if (flag == "--target")
            return "the machine decides which directory cargo writes a"
                   " program into, so write '--target TRIPLE' as a"
                   " CONFIGUREOPTS of its own";

        /* The escape hatch inside the escape hatch: a "--config"
         * reaches every setting cargo has, by name, and three of
         * those names are the three questions above said in cargo's
         * own words -- "build.target-dir", "build.target" and
         * "install.root".  It is refused whatever is in it rather
         * than read, because reading it would mean this build system
         * parsing TOML to find out whether a Configfile line meant
         * anything it had already decided, and because the value may
         * be the path of a file rather than a setting at all: cargo
         * takes "--config the-rest-of-it.toml" and reads whatever is
         * in there. */
        if (flag == "--config")
            return "a '--config' says any setting cargo has, three of which"
                   " are the ones above under cargo's own names --"
                   " 'build.target-dir', 'build.target' and 'install.root'"
                   " -- and it takes the name of a file to read them out of"
                   " as readily as it takes one of them, so it is refused"
                   " whatever is written after it";

        /* And the one that leaves the object directory outright.
         * This copies what was built to a directory of its own,
         * which is an absolute path in a recipe that runs during a
         * plain "make" -- the same escape an install prefix is, in
         * an option nobody thinks of as installing.  "--out-dir" is
         * what cargo called it before it was renamed, and a
         * "--cargo" old enough to still take it is exactly the case
         * a pinned toolchain is for. */
        if (flag == "--artifact-dir" || flag == "--out-dir")
            return "it copies what was built to a directory of its own,"
                   " which is this build running during a plain 'make' and"
                   " writing wherever that path pointed -- what a vendored"
                   " tree builds stays in this subproject's object"
                   " directory, and '--install DIR' is how a copy of it"
                   " gets somewhere this project owns";

        return "";
    }

    /* What a variable put in cargo's environment would be a second
     * answer to, or an empty "sets" for one this build system has no
     * opinion about.
     *
     * Cargo reads a great many variables and nearly every one of them
     * is the writer's business: a RUSTFLAGS, a CARGO_HOME, a linker
     * for a triple.  The four in here are not.  Each is the
     * environment's spelling of something this build system has
     * already written on cargo's own command line, and which of the
     * two cargo obeys is a detail of cargo rather than a thing
     * anybody meant.
     *
     * Three of them cargo happens to shadow today: a "--target-dir"
     * on the command line beats both CARGO_TARGET_DIR and
     * CARGO_BUILD_TARGET_DIR, and a "--root" beats CARGO_INSTALL_ROOT
     * -- and without an "--install" there is no install command for
     * the last of those to be about at all.  They are refused anyway,
     * because what is wrong with the line is not that it wins: a
     * Configfile that says where cargo builds and is silently
     * overruled says something that isn't true, and the day this
     * recipe stops writing one of those two flags is the day it
     * stops being untrue and starts being a build in somebody else's
     * directory.
     *
     * The fourth is not shadowed by anything.  A "--target" is
     * written only when a CONFIGUREOPTS asked for one, which is not
     * the usual case, so CARGO_BUILD_TARGET is read -- and every
     * program cargo builds moves down into a directory named after
     * the triple, while artifact_dir() out here goes on saying
     * "debug".  What that looks like is a SUBPROJECT_TARGETS that
     * stopped resolving, from a line that named no directory at
     * all. */
    struct settled {
        std::string sets;
        std::string advice;
    };

    settled reserved_variable(const std::string& variable)
    {
        if (variable == "CARGO_TARGET_DIR"
            || variable == "CARGO_BUILD_TARGET_DIR")
            return settled{
                "sets where cargo builds, which this build system decides"
                " for itself",
                "cargo's output goes in this subproject's object directory,"
                " which is what keeps it out of the vendored tree"};

        if (variable == "CARGO_BUILD_TARGET")
            return settled{
                "sets the machine cargo builds for, which decides which"
                " directory it writes a program into",
                "write '--target TRIPLE' as a CONFIGUREOPTS of its own,"
                " which is the same thing said where the rest of this build"
                " can read it"};

        if (variable == "CARGO_INSTALL_ROOT")
            return settled{
                "sets where cargo installs, which this build system decides"
                " for itself",
                "the install here runs during 'make' rather than during"
                " 'make install', so a destination this build system didn't"
                " decide is a plain 'make' writing wherever that line"
                " pointed -- write '--install DIR', which names a directory"
                " inside this project's object directory"};

        return settled{"", ""};
    }

    /* Every file under a directory that could be worth re-running
     * cargo over, as a flat list.
     *
     * Only the kinds of file that decide what cargo does: the Rust,
     * the manifests, the lock file and cargo's own configuration.  A
     * crate can read anything at all through include_str!, and
     * chasing that would mean naming every byte in the tree -- which
     * for a crate with test fixtures in it is a Makefile made mostly
     * of fixtures.
     * Being wrong in the direction of running cargo when it needn't
     * have is cheap, because cargo then decides nothing changed and
     * says so in well under a second.
     *
     * Two things are skipped on the way down.  A directory called
     * "target" is cargo's own output, which is never here when
     * pconfigure put it where it belongs but is very often here when
     * somebody ran cargo by hand in the tree first -- and it holds
     * tens of thousands of files, every one of them a file the build
     * produces rather than reads.  A directory holding a
     * CACHEDIR.TAG is the same thing under some other name, which is
     * what that file is for and what cargo writes into its target
     * directory to say so.
     *
     * Symlinks are skipped outright rather than followed.  A crate
     * that reaches its sources through one is rare, and a walk that
     * follows them is a walk that a link pointing at its own parent
     * never comes back from. */
    void walk(const std::string& dir, size_t depth,
              std::vector<std::string>& out)
    {
        if (depth == 0)
            return;

        auto handle = opendir(dir.c_str());
        if (handle == NULL)
            return;

        /* Whether this is the ".cargo" the rule below lets the walk
         * into, which is the one directory where a file with no
         * extension on it is worth looking at: see the filter at the
         * bottom. */
        auto slash = dir.find_last_of('/');
        auto dot_cargo =
            (slash == std::string::npos ? dir : dir.substr(slash + 1))
            == ".cargo";

        struct dirent *entry;
        while ((entry = readdir(handle)) != NULL) {
            auto name = std::string(entry->d_name);

            /* "." and ".." are where a walk goes in circles, and
             * everything else starting with a '.' is somebody's
             * bookkeeping -- ".git" above all, which is bigger than
             * the crate.
             *
             * ".cargo" is the one exception, and it's a named one
             * rather than a hole in the rule: the config.toml in
             * there -- or the "config" beside it, which is the older
             * spelling of the same file and one cargo still reads --
             * is where a vendored crate pins its rustflags, its
             * linker and above all the "[source.crates-io]
             * replace-with" that makes an offline build out of a
             * vendored registry.  It decides what cargo does as
             * surely as the Cargo.toml does, so editing it has to be
             * a reason to run cargo again. */
            if (name.size() == 0
                || (name[0] == '.' && name != ".cargo"))
                continue;

            auto path = dir + "/" + name;

            struct stat buf;
            if (lstat(path.c_str(), &buf) != 0)
                continue;

            if (S_ISDIR(buf.st_mode) == true) {
                if (name == "target")
                    continue;
                if (access((path + "/CACHEDIR.TAG").c_str(), R_OK) == 0)
                    continue;

                walk(path, depth - 1, out);
                continue;
            }

            if (S_ISREG(buf.st_mode) == false)
                continue;

            /* The three extensions, and then the one file that
             * hasn't got one: cargo's older spelling of its own
             * configuration is ".cargo/config" rather than
             * ".cargo/config.toml", and cargo still reads it.  It is
             * deprecated rather than gone, which means a crate that
             * has one is a crate configured out of it -- so letting
             * the walk into ".cargo" and then dropping the file on
             * the way past would be letting it in for nothing, and
             * would leave exactly the hole the exception was written
             * to close: a rustflags or a replaced registry that can
             * be edited without anything running cargo again.
             *
             * The name is only taken in that one directory, because
             * "config" is a common enough name for a file that
             * decides nothing. */
            if (string_utils::has_extension(name, ".rs")
                || string_utils::has_extension(name, ".toml")
                || string_utils::has_extension(name, ".lock")
                || (dot_cargo == true && name == "config"))
                out.push_back(path);
        }

        closedir(handle);
    }
}

bool build_system_cargo::handle_configureopt(const std::string& opt)
{
    /* The flags that take no value are compared outright rather than
     * read with option_value(), which answers "" both for "this isn't
     * my flag" and for "my flag was given nothing" and so can't tell
     * a bare "--release" from a line that isn't about release at all.
     * Every CONFIGUREOPTS has already had its whitespace tidied by
     * the time it gets here, so there is nothing else for these to
     * be. */
    if (opt == "--release") {
        _profile = "release";
        return true;
    }

    if (opt == "--all-features") {
        _all_features = true;
        return true;
    }

    if (opt == "--no-default-features") {
        _no_default_features = true;
        return true;
    }

    if (opt == "--locked") {
        _locked = true;
        return true;
    }

    if (opt == "--offline") {
        _offline = true;
        return true;
    }

    auto cargo = option_value(opt, "--cargo");
    if (cargo.size() > 0) {
        /* A path written here is resolved against the project and
         * written into the recipe absolutely, because the recipe runs
         * from inside the crate -- see cargo_program().  That only
         * works on a path pconfigure can read, so a make expression
         * is refused rather than resolved on top of: an "$(abspath
         * tools/cargo)" wrapped in an "$(abspath)" of our own is one
         * absolute path stuck on the end of another, which make
         * builds without a word and the shell then can't find.
         *
         * It's refused whether or not there's a '/' in it, since a
         * variable this can't expand is a variable that could hold
         * either kind of name. */
        if (cargo.find('$') != std::string::npos) {
            std::cerr << name() << ": '--cargo " << cargo << "' is a make"
                      << " expression, and this has to resolve the path"
                      << " itself\n"
                      << "  cargo is run from inside the crate, so a"
                      << " relative '--cargo' is resolved against the"
                      << " project that vendored the tree and written out"
                      << " absolutely\n"
                      << "  write it the way the project spells it, like"
                      << " '--cargo tools/cargo'\n";
            abort();
        }

        /* And a space is refused for a reason of its own, which is
         * the shape of what comes back rather than what is in it: a
         * "--cargo" is written into the recipe as one quoted word,
         * because it is a path somebody spelled and a directory is
         * allowed a space in its name.  So a "--cargo cargo
         * +nightly" -- which is how rustup is told which toolchain
         * to use, and the one way anybody writes two words here --
         * reaches the shell as the name of a program called "cargo
         * +nightly", which nobody has.  It read as two words before
         * the quoting went in, so this is the one spelling that used
         * to do something and now cannot: it is refused where it was
         * written rather than left to fail at "command not found" in
         * the middle of a build.
         *
         * The manual and the header both say a "--cargo" is a
         * program name or a path -- one word -- so this is the rule
         * being enforced rather than a new one, and it is the same
         * rule "--profile" and "--target" keep for the same reason:
         * one word, because what it names is one thing. */
        if (cargo.find(' ') != std::string::npos) {
            std::cerr << name() << ": '--cargo " << cargo << "' isn't a"
                      << " program: a '--cargo' is one word, a program name"
                      << " or a path to one\n"
                      << "  it is written into the recipe as a single quoted"
                      << " word, since a directory is allowed a space in its"
                      << " name -- so the words after the first would be"
                      << " part of the program's name rather than arguments"
                      << " handed to it\n"
                      << "  a toolchain is picked with the environment"
                      << " instead, like '--env RUSTUP_TOOLCHAIN=nightly',"
                      << " or by pointing '--cargo' at a script of your own"
                      << " that says the rest\n";
            abort();
        }

        _cargo = cargo;
        return true;
    }

    auto profile = option_value(opt, "--profile");
    if (profile.size() > 0) {
        /* A profile is a directory name as much as it is a setting --
         * it's the directory cargo writes what it built into -- so a
         * value with a path in it would name a program somewhere this
         * build system would never look for it. */
        if (profile.find('/') != std::string::npos
            || profile.find(' ') != std::string::npos) {
            std::cerr << name() << ": '--profile " << profile << "' isn't a"
                      << " profile name: a profile is one word, and it's the"
                      << " name of the directory cargo builds into\n"
                      << "  write something like '--profile release'\n";
            abort();
        }

        _profile = profile;
        return true;
    }

    auto target = option_value(opt, "--target");
    if (target.size() > 0) {
        /* And so is a triple, for the same reason: cargo puts a
         * directory named after it in front of the profile. */
        if (target.find('/') != std::string::npos
            || target.find(' ') != std::string::npos) {
            std::cerr << name() << ": '--target " << target << "' isn't a"
                      << " target triple: it's one word, and it's the name"
                      << " of a directory cargo builds into\n"
                      << "  write something like"
                      << " '--target riscv64gc-unknown-linux-gnu'\n";
            abort();
        }

        _target = target;
        return true;
    }

    auto package = option_value(opt, "--package");
    if (package.size() > 0) {
        _packages.push_back(package);
        return true;
    }

    auto bin = option_value(opt, "--bin");
    if (bin.size() > 0) {
        _bins.push_back(bin);
        return true;
    }

    auto features = option_value(opt, "--features");
    if (features.size() > 0) {
        /* Handed over as one word, because cargo is the thing that
         * knows how to read a feature list: it takes spaces and
         * commas alike, and a project that wrote one kind meant that
         * kind. */
        _features.push_back(features);
        return true;
    }

    auto jobs = option_value(opt, "--jobs");
    if (jobs.size() > 0) {
        for (const auto& c: jobs) {
            if (isdigit((unsigned char)c) != 0)
                continue;

            std::cerr << name() << ": '--jobs " << jobs << "' isn't a number"
                      << " of jobs\n"
                      << "  write how many cargo may run at once, like"
                      << " '--jobs 4'\n";
            abort();
        }

        _jobs = jobs;
        return true;
    }

    auto arg = option_value(opt, "--arg");
    if (arg.size() > 0) {
        /* An extra argument is an escape hatch, and an escape hatch
         * that can be used to say something this build system has
         * already decided is a way of getting two answers to one
         * question.  The flag is the first word of it, however it was
         * spelled: "--target-dir x" and "--target-dir=x" are the same
         * argument written two ways. */
        auto word = arg.substr(0, arg.find_first_of(" ="));
        auto advice = reserved_advice(reserved_flag(word));
        if (advice.size() > 0) {
            std::cerr << name() << ": '--arg " << arg << "' passes '" << word
                      << "', which this build system decides for itself\n"
                      << "  " << advice << "\n";
            abort();
        }

        _args.push_back(arg);
        return true;
    }

    auto env = option_value(opt, "--env");
    if (env.size() > 0) {
        /* What an --env is allowed to look like is one question with
         * one answer for every build system here, so it is asked in
         * one place: see build_system::checked_env(), which is where
         * the rule this used to keep to itself now lives.  Three
         * other build systems had the same option and asked only for
         * an '=', so the line this refused was accepted by them and
         * turned into an Error 127 in the middle of a build. */
        checked_env("--env", env, "RUSTFLAGS=-C target-cpu=native");

        /* And then the variables that would undo something this
         * build system has already said on cargo's command line --
         * where it builds, which machine it builds for, where it
         * installs.  They are checked here rather than left to fight
         * it out down there because which of two answers cargo obeys
         * is a detail of cargo rather than a thing anybody meant:
         * see reserved_variable(), which is where the four of them
         * and the reasons are written.
         *
         * The name is the whole of what is compared, rather than the
         * front of the line: "CARGO_TARGET_DIR=x" is one of these
         * and a "CARGO_TARGET_DIR_TWO=x" somebody's build script
         * reads is not.  checked_env() above has already made sure
         * there is an '=' in here and that what is in front of it is
         * a name, so this finds one. */
        auto already = reserved_variable(env.substr(0, env.find('=')));
        if (already.sets.size() > 0) {
            std::cerr << name() << ": '--env " << env << "' "
                      << already.sets << "\n"
                      << "  " << already.advice << "\n";
            abort();
        }

        _env.push_back(env);
        return true;
    }

    auto install = option_value(opt, "--install");
    if (install.size() > 0) {
        /* Nothing is asked about it here: where an install root may
         * point is one question with one answer for every vendored
         * build system, and it needs the project the build system was
         * bound to, which a CONFIGUREOPTS written under a
         * BUILD_SYSTEMS hasn't got.  install_root() asks. */
        _install_root = install;
        return true;
    }

    auto depend = option_value(opt, "--depend");
    if (depend.size() > 0) {
        _depends.push_back(depend);
        return true;
    }

    return false;
}

std::string build_system_cargo::configureopt_help(void) const
{
    return "  '--cargo PATH' picks which cargo to run\n"
           "  '--profile NAME' or '--release' picks the profile to build"
           " with\n"
           "  '--target TRIPLE' builds for another machine\n"
           "  '--package NAME' picks a member of a workspace\n"
           "  '--bin NAME' picks one of the programs a crate builds\n"
           "  '--features LIST', '--all-features' and"
           " '--no-default-features' pick features\n"
           "  '--locked' builds against the committed Cargo.lock\n"
           "  '--offline' builds without asking the network\n"
           "  '--jobs N' bounds how many jobs cargo runs at once\n"
           "  '--arg TEXT' passes one more argument to 'cargo build'\n"
           "  '--env NAME=VALUE' puts a variable in the environment it runs"
           " in\n"
           "  '--install DIR' installs what was built into a directory\n"
           "  '--depend PATH' waits for something else before building\n";
}

void build_system_cargo::take_configureopt(const std::string& opt)
{
    if (handle_configureopt(opt) == true)
        return;

    std::cerr << name() << ": unknown CONFIGUREOPTS '" << opt << "'\n"
              << configureopt_help();
    abort();
}

std::string build_system_cargo::cargo_program(void) const
{
    /* A word with no '/' in it is a program name rather than a path,
     * and a program name means the same thing from every directory:
     * the shell searches the PATH for it, and the PATH is not
     * relative to anywhere.  This is the default and very nearly
     * always what's there, so the interesting cases below are the
     * rare ones. */
    if (_cargo.find('/') == std::string::npos)
        return _cargo;

    /* An absolute path is already the one thing a path can be that
     * survives a change of directory. */
    if (_cargo[0] == '/')
        return _cargo;

    /* And a relative one is read the way the project that vendored
     * the tree spells it, the same as an "--install" is, because that
     * project is who wrote it: "--cargo tools/cargo" is a statement
     * about the pinned toolchain sitting beside the Configfile.  It
     * has to be made absolute rather than left alone, since the
     * recipe it lands in has already gone "cd" into the crate and
     * "tools/cargo" down there is a different file -- usually no file
     * at all, and in a tree that happens to have a "tools" of its own
     * a program nobody meant to run.
     *
     * It goes through the same check a path out of a Configfile
     * always goes through, and for a reason that has nothing to do
     * with installing: a "--cargo ../tools/cargo" resolved against
     * whoever ran pconfigure names one program from the top of the
     * tree and a different one from inside the project, so the line
     * would say which cargo to run and not mean it.  A prefix is
     * where that bites hardest, but it is not where it starts.
     *
     * make does the conversion for the same reason it does it for
     * the manifest: "$(abspath)" is expanded where make is, which is
     * the directory the paths this writes are all relative to, and
     * it happens before the "cd" the shell hasn't run yet. */
    return "$(abspath "
         + checked_project_path("--cargo", _cargo, "tools/cargo") + ")";
}

std::string build_system_cargo::with_env(const std::string& command) const
{
    auto out = std::string();

    for (const auto& env: _env) {
        /* The value is quoted and the name is not, which is the only
         * way round that leaves a shell assignment in front of a
         * command: see the comment on this function.  What makes the
         * bare name safe rather than merely necessary is that
         * handle_configureopt() has already refused anything that
         * isn't a variable name -- and it is also what put the '=' in
         * every one of these, so the split below always finds one. */
        auto equals = env.find('=');
        out += env.substr(0, equals + 1)
             + string_utils::quoted(env.substr(equals + 1))
             + " ";
    }

    return out + command;
}

std::string build_system_cargo::selection_flags(
    const std::string& profile) const
{
    auto out = std::string();

    /* Said the same way whichever profile it is, rather than
     * "--release" for one of them and "--profile" for the rest: one
     * spelling in a generated Makefile is one thing to read.  Which
     * profile that is is the caller's to say, since the two
     * subcommands this builds a command line for don't default to the
     * same one. */
    if (profile.size() > 0)
        out += " --profile " + string_utils::quoted(profile);

    if (_target.size() > 0)
        out += " --target " + string_utils::quoted(_target);

    for (const auto& bin: _bins)
        out += " --bin " + string_utils::quoted(bin);

    for (const auto& features: _features)
        out += " --features " + string_utils::quoted(features);

    if (_all_features == true)
        out += " --all-features";

    if (_no_default_features == true)
        out += " --no-default-features";

    if (_locked == true)
        out += " --locked";

    if (_offline == true)
        out += " --offline";

    /* The one thing on this line that isn't quoted, because it is the
     * one thing that has already been proved to be a single word: an
     * option that wasn't digits all the way through was refused where
     * it was written, so there is nothing left in here for a shell to
     * find.  Everything above it came out of a Configfile as text
     * somebody is entitled to have written a space into. */
    if (_jobs.size() > 0)
        out += " --jobs " + _jobs;

    return out;
}

std::string build_system_cargo::build_only_flags(void) const
{
    auto out = std::string();

    /* "cargo install" hasn't got this one.  It takes a "--path" and
     * installs what's there, so the way to install one member of a
     * workspace is to point at the member -- which is why a
     * "--package" written together with an "--install" is refused
     * outright rather than quietly dropped from one of the two
     * command lines. */
    for (const auto& package: _packages)
        out += " --package " + string_utils::quoted(package);

    return out;
}

std::string build_system_cargo::install_profile(void) const
{
    /* Never nothing, which is the whole point: "cargo build" with no
     * "--profile" builds "dev" and "cargo install" with no
     * "--profile" builds "release".  Left to their defaults the two
     * halves of this recipe would compile the crate twice, and the
     * copy that reached the install root would be the one build_dir()
     * -- and so every SUBPROJECT_TARGETS, every TESTDEPS and every
     * link line -- isn't pointing at.
     *
     * "dev" rather than anything cleverer because that is what
     * artifact_dir() already assumes an unsaid profile is, and these
     * two have to agree: one of them names the directory cargo writes
     * into and the other names the directory everything else reads
     * out of. */
    if (_profile.size() == 0)
        return "dev";

    return _profile;
}

std::string build_system_cargo::install_root(void) const
{
    /* The directory is written relative to the project that asked for
     * it, the same way a SUBPROJECTS is, since that's the project it
     * belongs to -- and it's resolved here rather than when the
     * option was read, because an option is read while this build
     * system is still unbound and there is no project to be relative
     * to yet.
     *
     * Where it is allowed to point is the same question every build
     * system here asks about an install prefix, so it is asked in one
     * place and answered one way: see build_system::install_dir() for
     * what the cleaning targets do with this directory, and
     * build_system::checked_install_dir() for what it is not allowed
     * to name and why.  Staying out of the vendored crate is part of
     * that, and it is the rule the rest of this build system is
     * arranged around: cargo's habit of writing a "target" beside the
     * manifest is the whole reason "--target-dir" is decided out here
     * rather than left to cargo, and an install root aimed back into
     * the crate would put the files there by hand instead. */
    return checked_install_dir("--install", _install_root);
}

std::string build_system_cargo::install_dir(void) const
{
    /* A crate with no --install installs nothing, so there is no
     * directory for the cleaning targets to spare or to take. */
    if (_install_root.size() == 0)
        return "";

    return install_root();
}

std::string build_system_cargo::artifact_dir(void) const
{
    /* Cargo's own mapping, which is not one-to-one: the four profiles
     * it comes with share two directories between them, and a profile
     * somebody wrote themselves gets a directory of its own name.
     * Nothing about this is a choice made here -- it's read off what
     * cargo does -- but it has to be known out here anyway, because
     * it's the difference between a SUBPROJECT_TARGETS that resolves
     * and one that doesn't. */
    auto profile = std::string();
    if (_profile.size() == 0 || _profile == "dev" || _profile == "test")
        profile = "debug";
    else if (_profile == "release" || _profile == "bench")
        profile = "release";
    else
        profile = _profile;

    /* An explicit triple puts a directory in front of all of that,
     * and the absence of one doesn't: a build for this machine lands
     * one directory higher than a build for any other, even when the
     * triple names this machine. */
    if (_target.size() > 0)
        return _target + "/" + profile;

    return profile;
}

std::vector<std::string> build_system_cargo::source_deps(void) const
{
    auto out = std::vector<std::string>();

    /* Deep enough for any crate anybody has written and shallow
     * enough to stop rather than recurse forever if something on the
     * way down turns out to be stranger than it looked. */
    walk(source_dir(), 32, out);

    /* Sorted so that two runs over an unchanged tree write the same
     * Makefile.  readdir hands these back in whatever order the
     * filesystem felt like, and a prerequisite list that shuffles
     * itself is a diff nobody can read. */
    std::sort(out.begin(), out.end());
    out.erase(std::unique(out.begin(), out.end()), out.end());

    return out;
}

std::vector<makefile::target::ptr>
build_system_cargo::vendored_targets(
    const std::vector<build_system::ptr>& peers,
    const std::string& project_base __attribute__((unused))) const
{
    auto srcdir = source_dir();
    auto stamp = build_stamp();

    /* What make prints while cargo is running.  It's the name of the
     * build system doing it, the way it is everywhere else -- and
     * unlike kbuild there's no second word to be had, since the one
     * program that runs here is the one whose name this is. */
    auto label = name();
    for (auto& c: label)
        c = toupper(c);

    /********************************************************************
     * The build                                                        *
     ********************************************************************/
    /* One rule, because cargo is one command.  A kbuild tree is
     * configured by one rule and built by another because those
     * really are two runs of two different things; cargo reads the
     * manifest, works out what has to happen and does it, and there
     * is no moment in the middle where the tree is configured and not
     * yet built for a rule to hang off. */
    auto deps = std::vector<makefile::target::ptr>();

    /* Through "$(wildcard)", as one prerequisite rather than
     * hundreds, because these were worked out by looking at the tree
     * and the tree moves.  Only the paths that existed at the moment
     * of configuring are in here, and every submodule bump deletes
     * some -- after which make has a prerequisite nothing can build
     * and refuses to build anything at all, not just this subproject.
     * $(wildcard) is re-expanded every run, so a file that has gone
     * away stops being named and one that comes back starts again. */
    auto sources = source_deps();
    if (sources.size() > 0)
        deps.push_back(std::make_shared<makefile::target>(
            "$(wildcard " + string_utils::join(sources, " ") + ")"));

    /* What this run was told, which has to be a prerequisite because
     * nothing else here is: every other file above is one the crate
     * already had, so a build reconfigured with different options
     * would find all of them exactly as it left them and do nothing.
     * pconfigure writes this one, and rewrites it only when it says
     * something different than it did last time.
     *
     * It hangs off the build because there is nowhere else for it to
     * hang: this build system has one rule.  That's the one thing
     * that gets simpler for having no configure step of its own. */
    deps.push_back(std::make_shared<makefile::target>(
        configureopts_file()));

    for (const auto& depend: _depends)
        deps.push_back(std::make_shared<makefile::target>(
            resolve_depend("--depend", depend, peers)));

    /* Both of these absolutely, and both for the same reason: cargo
     * writes the paths it was given into the fingerprints and the
     * dependency files it keeps in its target directory, so a build
     * run from the top of the tree and a build run from inside a
     * subproject have to hand it the same two strings or the second
     * one decides everything is stale.  make does the conversion, at
     * the point where it knows what directory it's in.
     *
     * And both quoted, the way every path this recipe hands to a
     * shell is.  None of the paths in here is a name pconfigure made
     * up: the SUBPROJECTS line named the tree, the object directory
     * under it is named after the tree, and an "--install" and a
     * "--cargo" are written out by hand -- so a crate vendored into a
     * directory somebody called "it's" puts an apostrophe in most of
     * them at once.  Unquoted, that is not a path at all: the shell
     * reads the rest of the recipe as a string and dies at the end of
     * the line, during a build, a long way from the line that named
     * the directory.
     *
     * The quoting goes round the whole "$(abspath ...)" rather than
     * round the path inside it, because what a shell reads is the
     * recipe and the whole expression is what is written there.  What
     * that leaves inside the parentheses is an escape make hands
     * straight through -- abspath normalizes a path, it has no idea
     * the shell has quotes -- so the word the shell finally sees is
     * the absolute path and nothing else. */
    auto manifest =
        string_utils::quoted("$(abspath " + srcdir + "/Cargo.toml)");
    auto target_dir =
        string_utils::quoted("$(abspath " + cargo_target_dir() + ")");

    /* And the program itself, which is worked out rather than copied
     * for the third instance of the same reason: the recipe below
     * runs from inside the crate, so a path that was written
     * relative to the project has to be absolute before the "cd"
     * moves what it would mean.  See cargo_program().
     *
     * Quoted for the reason above and one of its own: what comes back
     * is either a path a Configfile wrote or the word "cargo", and
     * the first of those is as much somebody's spelling as the
     * install root is.  A quoted program name is still a program name
     * -- the shell takes the quotes off before it searches the PATH
     * -- so there is no case where this costs anything. */
    auto cargo = string_utils::quoted(cargo_program());

    auto build = cargo + " build"
               + " --manifest-path " + manifest
               + " --target-dir " + target_dir
               + selection_flags(_profile)
               + build_only_flags();

    /* Extra arguments go on the build alone.  They were written for
     * "cargo build", which takes a different set of arguments than
     * "cargo install" does, and quietly handing them to both is how
     * an escape hatch turns into a build that fails in the half
     * nobody was thinking about.
     *
     * Each is quoted whole, so one --arg is one argument to cargo
     * however many spaces are in it -- and make still expands what's
     * inside, which is what lets somebody write a path as
     * "$(abspath x)" and mean it. */
    for (const auto& arg: _args)
        build += " " + string_utils::quoted(arg);

    /* Run from inside the crate, which a "--manifest-path" is not a
     * substitute for: cargo looks for its own configuration in
     * ".cargo/config.toml" from the current directory upward, and
     * never beside the manifest it was pointed at.  A crate that
     * vendors its dependencies, pins its linker or sets its rustflags
     * that way builds correctly by hand and silently differently from
     * out here -- and worse, whatever ".cargo/config.toml" the
     * project that vendored it happens to have is what gets read
     * instead.  Every other build system here enters the tree it
     * builds; this one has no "make -C" to do it with, so it says so.
     *
     * Nothing else in the recipe has to move, because the two paths
     * that matter were already absolute for the fingerprint reason
     * above, and "$(abspath)" is make's rather than the shell's: it
     * is expanded where make is, before the "cd" ever happens. */
    auto enter = "cd " + string_utils::quoted(srcdir) + " && ";

    auto commands = std::vector<std::string>{
        /* Nothing has made this yet on a fresh checkout, and the
         * stamp at the end of the recipe goes in it. */
        "mkdir -p " + string_utils::quoted(output_dir()),
        enter + with_env(build),
    };

    if (_install_root.size() > 0) {
        /* Refused rather than passed on, because "cargo install" has
         * no "--package": it installs whatever its "--path" names.
         * Handing it one anyway is a build that fails after the build
         * half has already succeeded, with cargo's own "unexpected
         * argument" a long way from the two lines that caused it --
         * and quietly dropping it would install a different member of
         * the workspace than the one that was asked for. */
        if (_packages.size() > 0) {
            std::cerr << name() << ": '--package " << _packages[0]
                      << "' and '--install " << _install_root << "' can't"
                      << " both be given\n"
                      << "  'cargo install' has no '--package': it installs"
                      << " the crate its '--path' names\n"
                      << "  so point the SUBPROJECTS at the workspace"
                      << " member's own directory and drop the"
                      << " '--package'\n";
            abort();
        }

        auto root = install_root();

        /* "--no-track" is what keeps this out of the business of the
         * directory it installs into: without it cargo writes a
         * .crates.toml and a .crates2.json next to the bin directory,
         * saying what it thinks lives there -- which is wrong the
         * moment anything else installs into the same prefix, and a
         * prefix shared between several vendored trees is the normal
         * case rather than the odd one.
         *
         * "--force" because a second install of the same crate is the
         * normal case here rather than a mistake: this is the build
         * rule's recipe, so it runs again for every source that
         * changes and every option that moves.  Without it cargo
         * refuses to overwrite the program it installed last time and
         * takes the build down with it -- and with "--no-track" there
         * is no tracking data for it to reconsider, so the file being
         * there is the whole of what it looks at.
         *
         * The same target directory as the build, and the same
         * profile spelled out, so this is a re-install of what was
         * just built rather than a second build of the same crate
         * into a directory of its own. */
        commands.push_back("mkdir -p " + string_utils::quoted(root));
        commands.push_back(enter + with_env(
            cargo + " install"
            + " --path " + string_utils::quoted("$(abspath " + srcdir + ")")
            + " --root " + string_utils::quoted("$(abspath " + root + ")")
            + " --target-dir " + target_dir
            + " --no-track"
            + " --force"
            + selection_flags(install_profile())));
    }

    /* Cargo says what it read, in a .d file beside every program it
     * builds, and none of that is used here.  It would take a program
     * of our own to read it -- psubdeps reads kbuild's *.cmd files
     * and nothing else -- and it would buy very little: cargo has
     * already decided nothing changed by the time anybody could look,
     * and the guess above only has to be good enough to keep make
     * from asking.  What the guess costs when it's wrong is one cargo
     * run that prints nothing.
     *
     * The stamp is named rather than written as "$@", which is the
     * one place in this recipe where the quoting decides how a path
     * is spelled rather than merely whether it is safe: an escape has
     * to be put in by whoever knows what the text is, and "$@" is
     * make handing the shell a path this code never looked at.  There
     * is nothing lost by saying it -- "$@" is this same string, which
     * is what makes the two interchangeable -- and a stamp under a
     * crate vendored into a directory with an apostrophe in its name
     * is a redirection the shell cannot parse. */
    commands.push_back("date > " + string_utils::quoted(stamp));

    auto build_target = std::make_shared<makefile::target>(
        stamp,
        label + "\t" + srcdir,
        deps,
        /* ALL is what makes a plain "make" build the crate.  CLEAN
         * takes the stamp and nothing else: what cargo built is
         * cargo's, and throwing away a target directory that cargo
         * would have reused is minutes of somebody's day in exchange
         * for nothing.  Losing the stamp is enough to make the next
         * "make" run cargo again, which is all a clean has to
         * promise. */
        std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        },
        commands,
        std::vector<std::string>{
            "The vendored build system in " + srcdir + ", which is run"
            " whenever one of the files it could read has changed"
        }
    );

    return std::vector<makefile::target::ptr>{build_target};
}
