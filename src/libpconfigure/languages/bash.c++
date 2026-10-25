/*
 * Copyright (C) 2015-2016 Palmer Dabbelt
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

#include "bash.h++"
#include "perl.h++"
#include "../language_list.h++"
#include "../pick_language.h++"
#include "../file_utils.h++"
#include "../string_utils.h++"
#include "../project.h++"
#include <pinclude.h++>
#include <assert.h>
#include <cstdint>
#include <functional>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <iostream>
#include <sstream>

/* The options pbashc is run with, split into words and with the
 * project's own "-I" directories said from the top of the tree. */
static std::vector<std::string>
pbashc_options(const std::vector<std::string>& opts,
               const std::string& base);

language_bash* language_bash::clone(void) const
{
    return new language_bash(this->list_compile_opts(),
                             this->list_link_opts());
}

bool language_bash::can_process(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::LIBRARY:
    case context_type::GENERATE:
    case context_type::HEADER:
    case context_type::PHONY:
        return false;

    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
    return language::all_sources_match(ctx, source_extensions());
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

const std::vector<std::string>& language_bash::source_extensions(void)
{
    static const std::vector<std::string> extensions = {".bash"};
    return extensions;
}

pinclude::syntax language_bash::syntax_of(const std::string& path)
{
    for (const auto& extension: language_bash::source_extensions())
        if (string_utils::has_extension(path, extension))
            return pinclude::syntax::SHELL;

    for (const auto& extension: language_perl::source_extensions())
        if (string_utils::has_extension(path, extension))
            return pinclude::syntax::PERL;

    return pinclude::syntax::C;
}

bool language_bash::targets_handle(const context::ptr& ctx)
{
    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::LIBRARY:
    case context_type::GENERATE:
    case context_type::PHONY:
        return false;

    /* A SOURCE is never built on its own, but it is asked about: the
     * answer for one is the answer BASH's own can_process() gives,
     * which is yes. */
    case context_type::HEADER:
    case context_type::BINARY:
    case context_type::SOURCE:
    case context_type::TEST:
        return true;
    }

    std::cerr << "Internal error: bad context type "
              << std::to_string(ctx->type)
              << "\n";
    abort();
}

/* The path components of a name, with "." and empty components dropped
 * and each ".." taking the component before it off where there is one.
 * This is only spelling: nothing is looked up on disk, so a symlink
 * followed by ".." is taken at its word. */
static std::vector<std::string> path_components(const std::string& path)
{
    auto out = std::vector<std::string>();
    std::stringstream ss(path);
    std::string c;
    while (std::getline(ss, c, '/')) {
        if (c.empty() || c == ".")
            continue;

        if (c == ".." && out.size() > 0 && out.back() != "..") {
            out.pop_back();
            continue;
        }

        out.push_back(c);
    }
    return out;
}

/* How the file at "from" would have to "#include" the one at "to".
 * pinclude looks a quoted include up in the directory of the file
 * doing the including before anywhere else, so the name is the one
 * that leads from that directory to the other file -- which is not the
 * name written in the Configfile once the sources are in a
 * subdirectory: "SOURCES += lib/b.bash" is reached from lib/a.bash as
 * "b.bash", and "lib/b.bash" there is looked for in lib/lib/. */
static std::string include_spelling(const std::string& from,
                                    const std::string& to)
{
    auto f = path_components(from);
    auto t = path_components(to);
    if (f.size() > 0)
        f.pop_back();

    size_t common = 0;
    while (common < f.size() && common + 1 < t.size() && f[common] == t[common])
        common++;

    auto out = std::string();
    for (size_t i = common; i < f.size(); ++i)
        out += "../";
    for (size_t i = common; i < t.size(); ++i)
        out += t[i] + (i + 1 < t.size() ? "/" : "");
    return out;
}

std::string
language_bash::second_source_advice(const context::ptr& first,
                                    const context::ptr& second,
                                    const std::string& spelling) const
{
    return "  write '#include \"" + spelling + "\"' in "
         + first->cmd->data()
         + " instead of a second SOURCES, or give "
         + second->cmd->data() + " a target of its own\n";
}

/* The paths in the recipes below are bare words, for the reason
 * written out over language_cxx::compile_source(): a name holding a
 * quote, a space or a shell metacharacter does not build anywhere in
 * pconfigure, quoting these recipes would not change that, and the
 * whole of it is on makefile::path_prefix and under "Odd Behavior" in
 * doc/pconfigure.tex. */
std::vector<makefile::target::ptr>
language_bash::targets(const context::ptr& ctx) const
{
    assert(ctx != NULL);

    switch (ctx->type) {
    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::LIBRARY:
    case context_type::SOURCE:
    case context_type::PHONY:
        std::cerr << "Unimplemented context type: "
                  << std::to_string(ctx->type)
                  << "\n";
        std::cerr << ctx->as_tree_string("  ");
        abort();
        break;

    case context_type::HEADER:
    case context_type::BINARY:
    {
        /* BASH-like languages are designed to be super simple: since
         * all they do is just link all the sources together at the
         * end, there's no need for any internal targets at all. */
        auto target = ctx->bin_dir + "/" + ctx->cmd->data();

        auto short_cmd = this->compiler_pretty() + "\t" + ctx->cmd->data();

        /* pbashc runs from the top of the tree, and so does the
         * search for what a script reads, so both are given the
         * options with a subproject's include directories rerooted
         * onto it -- the one list, so that they can't disagree about
         * where a helper is. */
        auto opts = pbashc_options(this->clopts(ctx), ctx->src_path);

        auto sources = std::vector<makefile::target::ptr>();
        auto deps = std::vector<makefile::target::ptr>();
        auto fragments = std::vector<makefile::target::ptr>();
        auto tests = std::vector<makefile::target::ptr>();
        context::ptr first = NULL;
        for (const auto& child: ctx->children) {
            /* The compiler is handed one input with "-i" and that file
             * is the whole output, so a second SOURCES has nowhere to
             * go.  It used to be made a prerequisite anyway and then
             * never handed over: an output that rebuilt every time the
             * file changed and never had a line of it inside.
             *
             * The same file named twice gets a message of its own.  It
             * did no harm before, but the advice below would have it
             * include itself, and all there is to do is delete the
             * line. */
            if (child->type == context_type::SOURCE && first != NULL) {
                auto first_path = first->src_dir + "/" + first->cmd->data();
                auto path = child->src_dir + "/" + child->cmd->data();
                auto where = first->cmd->debug()->filename() + ":"
                    + std::to_string(first->cmd->debug()->line_number());

                std::cerr << std::to_string(child->cmd->debug()) << "\n";
                if (path_components(path) == path_components(first_path)) {
                    std::cerr << "  error: '" << child->cmd->data()
                              << "' is already the SOURCES of '"
                              << ctx->cmd->data() << "', from "
                              << where << "\n"
                              << "  delete this line\n";
                    abort();
                }

                std::cerr << "  error: '" << ctx->cmd->data()
                          << "' is one " << this->one_source_noun()
                          << " made from one source, and it already has '"
                          << first->cmd->data() << "' from "
                          << where << "\n"
                          << this->second_source_advice(
                                 first, child,
                                 include_spelling(first_path, path));
                abort();
            }

            if (child->type == context_type::SOURCE) {
                first = child;
                auto path = child->src_dir + "/" + child->cmd->data();
                sources.push_back(std::make_shared<makefile::target>(path));

                /* What a script includes is what it depends on in
                 * exactly the sense a C source's headers are, since
                 * the compiler pastes them in -- so a project that
                 * asked for its dependencies to be worked out while
                 * it builds gets them that way here too.  The list
                 * pconfigure found was frozen into the rule, and a
                 * script that started including a file after the
                 * configure was never rebuilt when that file changed,
                 * while one that stopped including a file it then
                 * deleted had make stop on the file. */
                if (ctx->autodeps == true && ctx->autoreconfigure == true
                    && this->pastes_includes() == true)
                    fragments.push_back(
                        deps_script(ctx, child, target, opts));
                else if (ctx->autodeps == true)
                    deps = deps + dependencies(path, opts);
            }

            /* A test is a child of the thing it tests, and the project
             * only ever hands a language its output contexts -- so the
             * tests of a BASH binary are reached from here or they are
             * not reached at all.  They were not, and a TESTSRC under a
             * BASH binary built nothing and said nothing about it.  The
             * language is picked per test, because the test of a BASH
             * binary needn't be written in BASH. */
            if (child->type == context_type::TEST) {
                auto l = pick_language(ctx->languages, child);
                auto filtered_child = [&]() -> context::ptr
                    {
                        if (l->name() == this->name())
                            return child;

                        return child->without_clopts();
                    }();
                tests = tests + l->targets(filtered_child);
            }
        }

        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::ALL,
            makefile::global_targets::CLEAN,
        };

        auto command = std::string();
        command += this->compiler_command(ctx)
                   + " -i "
                   + sources[0]->name()
                   + " -o "
                   + target;

        for (const auto& str: opts)
            command += " " + str;

        auto bin_subdir = target.substr(0, target.find_last_of("/"));

        auto commands = std::vector<std::string>{
            "mkdir -p " + bin_subdir,
            command
        };

        /* The recipe rides the rule as a prerequisite, so that a
         * reconfigure that changed a "-DNAME=value", moved a "-I" or
         * pointed the target at a different SOURCES builds it again:
         * see recipe_record(). */
        auto recipe_inputs = std::vector<makefile::target::ptr>{
            recipe_record(ctx, target, commands)
        };

        auto filename = ctx->cmd->debug()->filename();
        auto lineno = ctx->cmd->debug()->line_number();
        auto comment = std::vector<std::string>{
            "language_bash::targets() BINARY",
            filename + ":" + std::to_string(lineno)
        };

        auto bin_target = std::make_shared<makefile::target>(target,
                                                             short_cmd,
                                                             sources + deps + recipe_inputs,
                                                             global_targets,
                                                             commands,
                                                             comment);

        /* Targets that are never installed (TESTEXECs) just get built in
         * place, there's no install rule to go along with them. */
        if (ctx->install == false)
            return std::vector<makefile::target::ptr>{bin_target}
                   + fragments + tests;

        auto install_path = "$(DESTDIR)" + ctx->installed(target);

        /* Whatever "make install" writes is something "make uninstall"
         * has to know how to take back out, and the only way it knows
         * is a target putting itself on both.  This rule used to name
         * just the one, so a script -- and a header or a perl script,
         * which are installed by this same code -- went in under the
         * prefix and stayed there after everything compiled beside it
         * had been removed. */
        auto global_install_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::INSTALL,
            makefile::global_targets::UNINSTALL,
        };

        /* Copied next to where it goes and then renamed over it, for
         * the reason languages/cxx.c++ gives at more length: a "cp"
         * writes through the file that's already there, so a program
         * something has open is a program that changes underneath it
         * -- and on macOS, one whose code signature the kernel has
         * already checked and remembered against that same file.
         *
         * The copy is given a fixed mode before it's renamed into
         * place, the ones "install -m 644" and "install -m 755" give.
         * A "cp" carries over the build tree's mode, which is whatever
         * the builder's umask said: a tree built under "umask 077"
         * installed a header nobody else could read and a script
         * nobody else could run, since a script has to be read to be
         * run.  The build tree's copy keeps the builder's mode -- that
         * one is theirs -- and only what lands under the prefix, which
         * is for everyone, is changed. */
        auto install_mode = (ctx->type == context_type::HEADER)
                            ? std::string("0644")
                            : std::string("0755");

        auto install_commands = std::vector<std::string>{
            "mkdir -p $(DESTDIR)" + ctx->installed(bin_subdir),
#if defined(__gnu_linux__)
            "cp --reflink=auto -f " + target + " $@.tmp",
#else
            "cp -f " + target + " $@.tmp",
#endif
            "chmod " + install_mode + " $@.tmp",
            "mv -f $@.tmp $@"
        };

        auto install_target = std::make_shared<makefile::target>(install_path,
                                                                short_cmd,
                                                                std::vector<makefile::target::ptr>{bin_target},
                                                                global_install_targets,
                                                                install_commands,
                                                                comment);

        return std::vector<makefile::target::ptr>{bin_target, install_target}
               + fragments + tests;
    }

    case context_type::TEST:
    {
        auto child_ctx = ctx->dup(context_type::BINARY);
        child_ctx->bin_dir = ctx->obj_dir + "/" + ctx->unbased(ctx->check_dir);

        /* A test is run out of the build tree and never installed,
         * the way a TESTEXECS is, so it gets no install rule to begin
         * with.  languages/cxx.c++ builds its tests the same way,
         * and had to: filtering an installing BINARY's targets back
         * down after the fact left a C test's install link behind. */
        child_ctx->install = false;
        auto bin_name = ctx->test_binary;
        auto bin_targets = vector_util::map(targets(child_ctx),
                                            [](const makefile::target::ptr& t)
                                            {
                                                return t->without(makefile::global_targets::ALL);
                                            });
        /* The compiled test and nothing else of what a BINARY gets --
         * except for the fragment that says what the test reads, which
         * is as much a part of building it as the rule that does. */
        {
            auto kept = std::vector<makefile::target::ptr>{bin_targets[0]};
            for (size_t i = 1; i < bin_targets.size(); ++i)
                if (bin_targets[i]->included() == true)
                    kept.push_back(bin_targets[i]);
            bin_targets = kept;
        }
        /* A test under a PHONY has nothing it's testing, so there's
         * no program to wait for and none to hand it.  Everywhere
         * else this is the thing the test exercises. */
        auto deps = bin_targets;
        if (bin_name.size() > 0)
            deps = std::vector<makefile::target::ptr>{
                       std::make_shared<makefile::target>(bin_name)
                   } + deps;

        auto target_name = ctx->check_target();
        auto short_cmd = "CHECK\t" + ctx->cmd->data();
        auto global_targets = std::vector<makefile::global_targets>{
            makefile::global_targets::CHECK,
            makefile::global_targets::CLEAN
        };
        auto test_name = ctx->obj_dir + "/" + ctx->unbased(ctx->check_dir) + "/" + ctx->cmd->data();

        /* A test that needs something built before it runs says so
         * with a TESTDEPS, and all that has to happen is that make
         * builds it first.  Every one of them is something this
         * project builds, which is what keeps this Makefile usable
         * on its own.  It is a path as the Configfile wrote it, so it
         * is spelled for the rule line it lands on: a '#' left bare
         * there is a comment that cuts the path short. */
        for (const auto& dep: ctx->based_test_deps())
            deps.push_back(std::make_shared<makefile::target>(
                               makefile::prerequisite(dep)));

        /* A test that reads what another test left behind says so
         * with a DEPTESTS, and make ordering the two is the whole of
         * it: the tarball the first one leaves is a prerequisite, so
         * the second one waits for it and runs again whenever it is
         * rewritten.  Whether the first one passed is not make's
         * question -- a failed test is still a finished one, and it's
         * "make report" that has an opinion about the result. */
        for (const auto& dep: ctx->based_dep_tests())
            deps.push_back(std::make_shared<makefile::target>(dep));

        /* Where the project that owns this test is rooted -- whatever its
         * SRCPATH says, which is its own directory unless it said
         * otherwise.  make is what makes it absolute, because a test runs
         * wherever make was run and only make knows where that was.
         *
         * A test attached to a program can work this out from
         * $PTEST_BINARY.  One attached to a PHONY has no program to work
         * it out from, and this is what it anchors on instead of a
         * relative path with two answers.
         *
         * It is also the one word of this recipe that is not a path
         * pconfigure wrote itself: it is wherever somebody checked the
         * project out, which is not the project's choice, and a
         * "/home/me/my proj" pasted in as text reaches ptest as two
         * arguments, the second of which it has never heard of.  So it is
         * quoted, and make expanding the $(abspath) from inside the quotes
         * is exactly what's wanted, since make has no idea they are there.
         * What single quotes still can't carry is a checkout path with a
         * single quote in it, since make puts that in after the quoting
         * was decided.
         */
        auto srcdir = string_utils::quoted("$(abspath " + ctx->src_path + ".)");

        /* Scratch that does not get collected, named after the test and
         * sitting beside the test's own compiled self under $OBJDIR.
         *
         * Beside the test rather than in the check directory, which is
         * the obvious place and is wrong: "make report" walks a check
         * directory with find and reads every file it lands on as a
         * result tarball, so a disk image left in there is handed to tar
         * as though it were one test's verdict.  $OBJDIR is the other
         * directory a test already has to itself, it is on the same
         * volume as the tree -- which is what keeps a copy-on-write
         * clone of a fixture cheap -- and "make clean" already removes
         * it. */
        auto scratch_dir = test_name + ".scratch";

        /* The directory the result goes in is the one this target sits
         * in, which is the target's check directory only when the test
         * does.  A TESTSRC can name a file in a directory of its own --
         * "nested/deep.bash" -- and its tarball then lands in that
         * directory under the check directory; making only the check
         * directory left ptest writing to a path that wasn't there, so
         * the test never got a result at all.  The check directory itself
         * is still what --checkdir names, since that is where every test
         * of this target looks for the others' results.
         *
         * The "+" on ptest is what hands a test the jobserver, so a test
         * running a make of its own shares the outer "-j".  It also has make
         * run the line under "-n", "-t" and "-q", as it would a sub-make;
         * ptest is what declines to run the test then, because only a "+"
         * make can see before it expands the line gets the jobserver, so it
         * can't be left off for a dry run here. */
        auto commands = std::vector<std::string>{
            "mkdir -p $(dir $@)",
            "+" + makefile::tool_command("ptest") + " --test " + test_name + " --out " + target_name
                + (bin_name.size() > 0 ? " --bin " + bin_name : "")
                + " --srcdir " + srcdir
                + " --checkdir " + ctx->check_dir
                + " --scratchdir " + scratch_dir
        };
        auto comment = std::vector<std::string>{
            "language_bash::targets() CHECK"
        };
        auto check_target = std::make_shared<makefile::target>(target_name,
                                                               short_cmd,
                                                               deps,
                                                               global_targets,
                                                               commands,
                                                               comment)
            ->with_clean_extra(scratch_dir);

        return bin_targets + std::vector<makefile::target::ptr>{check_target};
    }
    }

    std::cerr << "context type not in switch\n";
    abort();
}

/* Every argument of "flag" on a pbashc command line, in either of the
 * two spellings pbashc reads: stuck on, or the word after the flag
 * when it stands alone.
 *
 * This is pbashc's reading rather than a compiler's, which is why it
 * isn't cxx_include_search(): pbashc knows "-I" and nothing else, and a
 * "-isystem" that this counted as a directory would be one the script
 * was never searched in.
 *
 * A line of COMPILEOPTS is a piece of a command line rather than one
 * word of it -- "-I inc" and "-Wall -Iinc" are each one line -- and
 * the shell is what splits it before pbashc sees it, so it is split
 * the same way here first, by the same splitter the C scan uses.  The
 * shell takes the quotes off as it splits, too, so -I'lib' reaches
 * pbashc as -Ilib and each argument here is the text the shell hands
 * over rather than the spelling it was written in: a directory called
 * "'lib'" is one nothing would ever be found in. */
static std::vector<std::string>
pbashc_flag_arguments(const std::vector<std::string>& opts,
                      const std::string& flag)
{
    auto words = std::vector<std::string>();
    for (const auto& opt: opts)
        for (const auto& word: string_utils::shell_words(opt))
            words.push_back(string_utils::shell_unescape(word));

    auto out = std::vector<std::string>();
    for (size_t i = 0; i < words.size(); ++i) {
        if (words[i].compare(0, flag.size(), flag) != 0)
            continue;

        if (words[i].size() > flag.size())
            out.push_back(words[i].substr(flag.size()));
        else if (i + 1 < words.size())
            out.push_back(words[++i]);
    }
    return out;
}

/* A subproject's "-I inc" means the inc/ beside its Configfile, and
 * pbashc is run from the top of the tree, where "inc" is some other
 * directory or none at all.  C has always had the subproject's
 * directory put on the front of it, and this does the same for the
 * one flag pbashc searches with, in either of the spellings
 * pbashc_flag_arguments() reads.  Each is given back spelled the way
 * it came in, since the Makefile's own rewriting of the subproject's
 * directory -- for a build run from inside it -- finds a path at the
 * start of a word or straight after "-I", and both spellings put it
 * in one of those places.
 *
 * Only "-I" is touched.  A "-D" is a name rather than a path, and
 * pbashc reads nothing else as a directory. */
static std::vector<std::string>
pbashc_options(const std::vector<std::string>& opts,
               const std::string& base)
{
    auto out = std::vector<std::string>();
    auto pending = false;
    for (const auto& opt: opts) {
        std::istringstream ss(opt);
        std::string word;
        while (ss >> word) {
            if (pending == true) {
                out.push_back(file_utils::reroot(base, word));
                pending = false;
            } else if (word == "-I") {
                out.push_back(word);
                pending = true;
            } else if (word.compare(0, 2, "-I") == 0) {
                out.push_back("-I" + file_utils::reroot(base, word.substr(2)));
            } else {
                out.push_back(word);
            }
        }
    }
    return out;
}

std::vector<std::string>
script_includes_read_by(const std::string& path,
                        const std::vector<std::string>& opts,
                        pinclude::syntax syntax)
{
    /* pbashc is run with the target's options, and it searches the
     * "-I" directories for an "#include" and reads the "-D" names in
     * an "#ifdef".  The list of what a script reads has to be found
     * the same way, or a helper that only those options lead to is
     * pasted into the script and then left off its prerequisites, so
     * that editing it never rebuilds the script.
     *
     * pinclude wants the names that are defined, and "-DNAME=value"
     * defines NAME, which is how pbashc reads it too. */
    auto include_dirs = pbashc_flag_arguments(opts, "-I");
    auto defined = std::vector<std::string>();
    for (const auto& define: pbashc_flag_arguments(opts, "-D"))
        defined.push_back(define.substr(0, define.find('=')));

    std::vector<std::string> out;
    /* A script's # is a comment leader, so nothing but the bare
     * "#include" that pbashc expands may be read as a directive here,
     * the lines are read the way pbashc reads them rather than the
     * way a C preprocessor would, and what is text rather than script
     * depends on which language the script is written in.  And an
     * "#if" is refused, because pbashc refuses it in either language:
     * a scan that worked one out could leave off a file pbashc would
     * have pasted in, or list one it would have stopped at. */
    pinclude::list(path,
                   include_dirs,
                   defined,
                   [&](std::string p) {
                       out.push_back(p);
                       return 0;
                   }, true, syntax, {}, true);
    return out;
}

std::vector<makefile::target::ptr>
language_bash::dependencies(const std::string& path,
                            const std::vector<std::string>& opts) const
{
    auto out = std::vector<makefile::target::ptr>();
    for (const auto& p: script_includes_read_by(path, opts, script_syntax()))
        out.push_back(std::make_shared<makefile::target>(p));
    return out;
}

/* The name pdeps writes a script's answer under, and the context it
 * reads to do it, have to tell apart every way one script is
 * compiled: a script can be the SOURCES of a binary and of a test of
 * something else, with other options and another output, and two of
 * those sharing a fragment would be each of them rewriting it for the
 * other.  The output and the whole command line are what differ, so
 * they are what is hashed -- the same arithmetic pdeps and
 * language_cxx name things with. */
static std::string script_hash(const std::vector<std::string>& words)
{
    std::hash<std::string> hash_fn;
    uint32_t seed = 5831;
    for (const auto& word: words)
        seed ^= hash_fn(word) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
    return std::to_string(seed);
}

makefile::target::ptr
language_bash::deps_script(const context::ptr& ctx,
                           const context::ptr& child,
                           const std::string& target,
                           const std::vector<std::string>& opts) const
{
    auto name = child->cmd->data();
    auto source_path = child->src_dir + "/" + name;
    auto hash = script_hash(
        std::vector<std::string>{target, this->compiler_command(ctx)}
        + opts);

    /* Halves rather than whole paths, as language_cxx writes them,
     * because that is what pdeps puts a name between. */
    auto dep_prefix =
        child->obj_dir + "/" + child->in_source_tree(child->src_dir) + "/";
    auto dep_suffix = "/" + hash + "-script.d";
    auto deps_path = dep_prefix + name + dep_suffix;

    /* Spelled with the writer in the name, for the reason
     * project::base_suffix() gives: a subproject is configured from
     * the top and from inside itself, each of those describes the
     * script from where it stands, and one file shared between them
     * would be rewritten by whichever ran last. */
    auto context_path = dep_prefix + name + "/" + hash + "-script-context"
        + project::base_suffix(child->base);

    auto say = [](const std::string& key, const std::string& value)
        { return key + " " + value + "\n"; };

    auto out = std::string();
    out += say("src-prefix", child->src_dir + "/");
    out += say("dep-prefix", dep_prefix);
    out += say("dep-suffix", dep_suffix);

    /* What makes this a script rather than a C source to pdeps, and
     * which of the two readings of one it is. */
    out += say("syntax",
               script_syntax() == pinclude::syntax::PERL ? "perl" : "shell");
    out += say("target", target);

    out += say("pdeps", makefile::tool_path("pdeps"));
    out += say("quiet", child->verbose ? "false" : "true");

    /* Where pdeps is standing is worked out the way it is for C: see
     * language_cxx::write_deps_context(). */
    if (child->base.size() > 0) {
        out += say("base", child->base);
        out += say("variable", project::prefix_variable(child->base));
        out += say("self", context_path);
    }

    for (const auto& opt: opts)
        out += say("opt", opt);

    /* Written only when it says something new, because it is a
     * prerequisite of the fragment: a context rewritten by every
     * configure is every script's includes looked for again. */
    file_utils::mkdir_p(dep_prefix + name);
    file_utils::write_configure_output(context_path, out);

    /* Through "$(wildcard)" for the reasons language_cxx::deps_source()
     * gives at length, which are all as true of a script: a deleted
     * source must not stop the build, and pdeps is named because a
     * fragment is what one version of it made of the script. */
    auto deps = std::vector<makefile::target::ptr>{
        std::make_shared<makefile::target>("$(wildcard " + source_path + ")"),
        std::make_shared<makefile::target>(context_path),
        std::make_shared<makefile::target>(
            "$(wildcard " + makefile::tool_path("pdeps") + ")")
    };

    auto commands = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        makefile::tool_command("pdeps")
            + " --context " + context_path
            + " --source " + name
    };

    return std::make_shared<makefile::target>(
        deps_path,
        "DEPS\t" + name,
        deps,
        std::vector<makefile::global_targets>{
            makefile::global_targets::CLEAN
        },
        commands,
        std::vector<std::string>{
            std::to_string(child->cmd->debug()),
            "language_bash::deps_script()"
        }
    )->as_included();
}

static void install_bash(void) __attribute__((constructor));
void install_bash(void)
{
    language_list::global_add(
        std::make_shared<language_bash>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
