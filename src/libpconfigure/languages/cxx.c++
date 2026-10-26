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

#include "cxx.h++"
#include <libmakefile/path_prefix.h++>
#include <libmakefile/self_path.h++>
#include "../language_list.h++"
#include "../vector_util.h++"
#include "../file_utils.h++"
#include "../string_utils.h++"
#include "../pick_language.h++"
#include "../project.h++"
#include <pinclude.h++>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <set>
#include <sstream>
#include <unordered_set>
#include <utility>

/* The directories a set of link arguments tells the linker to look
 * for libraries in. */
static std::vector<std::string> link_dirs(const std::vector<std::string>& args);

/* Turns a directory that's inside the tree being built back into the
 * relative path everything else uses to talk about it. */
static std::string relative_to_here(const std::string& dir);

/* The same, normalized, so two spellings of one directory compare
 * equal. */
static std::string canonical_dir(const std::string& dir);

/* The files already on disk that a set of link arguments has the
 * linker read, as the names to make them prerequisites under. */
static std::vector<std::string> link_input_files(const std::vector<std::string>& args);

/* Splits link arguments into words and re-roots the relative "-L"
 * directories among them at the project they were written in.
 *
 * A Configfile that says "-Lb/lib" means the "b/lib" next to it, the
 * same way "-Ib/include" does, and for the same reason: it was
 * written by somebody who only knew about their own project.  The
 * directories pconfigure adds itself are already rooted, so this only
 * ever sees what a Configfile asked for. */
static std::vector<std::string> reroot_link_opts(const std::vector<std::string>& opts,
                                                 const std::string& base)
{
    auto words = std::vector<std::string>();
    for (const auto& opt: opts)
        for (const auto& word: string_utils::shell_words(opt))
            words.push_back(word);

    if (base.size() == 0)
        return words;

    auto reroot = [&](const std::string& dir) {
        return file_utils::reroot(base, dir);
    };

    auto out = std::vector<std::string>();
    auto pending = false;
    for (const auto& word: words) {
        if (pending == true) {
            out.push_back(reroot(word));
            pending = false;
        } else if (word == "-L") {
            out.push_back(word);
            pending = true;
        } else if (word.compare(0, 2, "-L") == 0) {
            out.push_back("-L" + reroot(word.substr(2)));
        } else {
            out.push_back(word);
        }
    }

    return out;
}

/* The flags that add a directory to the include search, which are
 * the ones whose argument a subproject writes from its own directory
 * and the ones whose directories the header search has to look in.
 * "-I" is the only one of them short enough to be the two-character
 * flag that path_prefix knows takes its argument stuck on.
 *
 * clang's "-isystem-after" is one of them in its own right, not
 * "-isystem" with "-after" stuck on: it adds the next word to the end
 * of the system search.  It comes before "-isystem" here because the
 * flags are matched by what a word starts with, and the longer name
 * has to get the first look at a word or the shorter one takes it. */
static const std::vector<std::string>& include_flags(void)
{
    static const auto out = std::vector<std::string>{
        "-I", "-isystem-after", "-isystem", "-iquote", "-idirafter"
    };
    return out;
}

/* Splits an option into the flag it starts with, out of "flags", and
 * whatever is stuck on after it.  An empty flag means the word isn't
 * any of them.  The first flag a word starts with wins, so a flag
 * whose name starts with another's goes ahead of it in "flags". */
static std::pair<std::string, std::string>
split_flag(const std::string& word, const std::vector<std::string>& flags)
{
    for (const auto& flag: flags)
        if (word.compare(0, flag.size(), flag) == 0)
            return std::make_pair(flag, word.substr(flag.size()));
    return std::make_pair(std::string(), std::string());
}

/* What follows "flag" in a word as it was written, quoting and all,
 * where the word's unquoted text starts with "flag".  This walks the
 * word the way shell_unescape() does until it has gone past the
 * flag's characters, and gives back the rest.  A quote that opened
 * before the flag and is still open after it is opened again on the
 * front of what comes back, so '-Iinc' gives 'inc' and not inc', and
 * whatever the quoting was there for -- a space, or a "$$VAR" that
 * double quotes leave for the shell to expand -- reaches the shell the
 * way it was written. */
static std::string
written_argument(const std::string& word, const std::string& flag)
{
    auto quote = '\0';
    size_t seen = 0;
    size_t i = 0;
    while (i < word.size() && seen < flag.size()) {
        if (quote == '\'') {
            if (word[i] != '\'')
                seen++;
            else
                quote = '\0';
        } else if (quote == '"') {
            if (word[i] == '"')
                quote = '\0';
            else {
                if (word[i] == '\\' && i + 1 < word.size()
                    && std::string("$`\"\\").find(word[i+1]) != std::string::npos)
                    i++;
                seen++;
            }
        } else if (word[i] == '\'' || word[i] == '"') {
            quote = word[i];
        } else {
            if (word[i] == '\\' && i + 1 < word.size())
                i++;
            seen++;
        }
        i++;
    }

    /* A quote that closes right where the flag does would only come
     * back as an empty pair on the front, so it is left off. */
    if (quote != '\0' && i < word.size() && word[i] == quote)
        return word.substr(i + 1);
    if (quote != '\0')
        return std::string(1, quote) + word.substr(i);
    return word.substr(i);
}

pinclude::search_path
cxx_include_search(const std::vector<std::string>& opts)
{
    /* The compiler doesn't search these in the order they were
     * written, it searches them by kind and only goes by the written
     * order among flags of the same kind.  A quoted include looks in
     * every "-iquote" directory first, and an angled one not at all;
     * then both look along every "-I", then every "-isystem", then
     * the system's own directories, which clang's "-isystem-after"
     * adds to the end of, and last of all every "-idirafter", which
     * is only ever a fallback.  A scan that took them in written
     * order would let an "-isystem" or "-idirafter" written first
     * shadow an "-I" the compiler prefers, and would name the header
     * the compiler didn't read: the object would miss edits to the
     * one it did, and the source behind the wrong one would be
     * linked in.
     *
     * Each flag is asked about on its own rather than through
     * include_flags() at once, which keeps the order within a kind
     * and needs no telling apart afterwards.  "-isystem" is asked
     * with "-isystem-after" ahead of it for the reason include_flags()
     * puts it there: a word that starts with the longer name is that
     * flag and not the shorter one.
     *
     * Each directory comes back as the text it stands for rather than
     * as the shell would be handed it, since what's asked of these is
     * where to look on the disk.  The quotes come off before the word
     * is matched against the flags, not just off what follows the
     * flag: a quote may open before the flag as easily as after it,
     * and '-Iinc' is the compiler's -Iinc, but matched as written it
     * starts with a quote rather than "-I", and the directory was
     * passed over as though it were some other option. */
    auto of = [&](const std::string& flag) {
        auto out = std::vector<std::string>();
        auto pending = std::string();
        for (const auto& opt: opts) {
            auto word = string_utils::shell_unescape(opt);
            if (pending.size() > 0) {
                if (pending == flag)
                    out.push_back(word);
                pending = "";
                continue;
            }

            auto split = split_flag(word, include_flags());
            if (split.first.size() == 0)
                continue;
            if (split.second.size() == 0)
                pending = split.first;
            else if (split.first == flag)
                out.push_back(split.second);
        }
        return out;
    };

    return pinclude::search_path(of("-iquote"),
                                 of("-I")
                                 + of("-isystem")
                                 + of("-isystem-after")
                                 + of("-idirafter"));
}

/* The flags that have the compiler read a file before the source:
 * "-include" reads it as though the source's first line had included
 * it, and "-imacros" reads it for its macros alone.  Both take the
 * file stuck on or as the next word, like "-I".
 *
 * clang has an "-include-pch" whose argument is a precompiled header,
 * which is no file the scan could read and none it should go looking
 * for by "-pch".  Nothing that is a forced include starts with
 * "-include-", since gcc would have to be asked for a header whose
 * name starts with a '-', so any word that does is left alone. */
static std::pair<std::string, std::string>
split_forced_include(const std::string& word)
{
    if (word.compare(0, 9, "-include-") == 0)
        return std::make_pair(std::string(), std::string());
    return split_flag(word, std::vector<std::string>{"-imacros", "-include"});
}

static std::vector<std::string>
cxx_forced_includes(const std::vector<std::string>& opts)
{
    /* gcc reads every "-imacros" before any "-include", whatever order
     * they were written in, and the order matters to the scan for the
     * same reason it matters to the compiler: a file can test what
     * one read ahead of it defined. */
    auto imacros = std::vector<std::string>();
    auto includes = std::vector<std::string>();
    auto pending = std::string();

    /* Each is a file to be looked for, so like an include directory it is
     * wanted as the text the shell hands the compiler: a name written
     * as -include 'config.h' is looked for as config.h, not as a file
     * with quotes in its name that no directory has.
     *
     * Also like an include directory, the quotes come off before the
     * word is matched, not just off the name after the flag: a quote
     * that opens first, as in '-includeconfig.h', is the shell's all
     * the same, but the word as written starts with a quote rather
     * than "-include", and the file the compiler reads was never
     * scanned. */
    for (const auto& opt: opts) {
        auto word = string_utils::shell_unescape(opt);
        if (pending.size() > 0) {
            (pending == "-imacros" ? imacros : includes).push_back(word);
            pending = "";
            continue;
        }

        auto split = split_forced_include(word);
        if (split.first.size() == 0)
            continue;
        if (split.second.size() == 0)
            pending = split.first;
        else
            (split.first == "-imacros" ? imacros : includes)
                .push_back(split.second);
    }

    return imacros + includes;
}

std::vector<std::string>
cxx_defines(const std::vector<std::string>& opts)
{
    /* pinclude wants the names that are defined, and "-DNAME=value"
     * defines NAME every bit as much as "-DNAME" does.  Handed the
     * whole of "NAME=value" it would look for a macro by that name,
     * which no #ifdef has ever asked about.
     *
     * The same goes for a function-like "-DNAME(args)" or
     * "-DNAME(args)=body": the parameter list belongs to the
     * definition, and the name is what comes before it.  Cut only at
     * the '=', the name came out as "NAME(args)", so an "#ifdef NAME"
     * looked off and the scan followed a branch the compiler skips.
     *
     * A "-U" takes a name away again, and the compiler reads the two
     * in the order they're written: "-DTRACE -UTRACE" leaves TRACE
     * undefined and "-UTRACE -DTRACE" leaves it defined.  That's how
     * a target cancels a define its language's COMPILEOPTS gave every
     * target, since the target's options come after the language's.
     * Reading only the "-D"s kept such a name defined, so the scan
     * followed the "#ifdef"s the compiler skips and missed the
     * "#ifndef"s it takes -- listing headers that are never read,
     * linking in the sources behind them, and leaving out the ones
     * that are.  So the two are walked together, in order, each
     * spelling of each as cxx_include_search() takes its flags, and
     * with the quotes off before the word is matched, as it does: a
     * name with parentheses in it has to be quoted, and
     * '-DLOG(x)=(x)' is the compiler's -DLOG(x)=(x) even though the
     * word as written starts with a quote rather than "-D". */
    auto out = std::vector<std::string>();
    auto pending = std::string();
    auto apply = [&](const std::string& flag, const std::string& arg) {
        auto name = arg.substr(0, arg.find_first_of("=("));
        out.erase(std::remove(out.begin(), out.end(), name), out.end());
        if (flag == "-D")
            out.push_back(name);
    };
    for (const auto& opt: opts) {
        auto word = string_utils::shell_unescape(opt);
        if (pending.size() > 0) {
            apply(pending, word);
            pending = "";
            continue;
        }

        auto split = split_flag(word, std::vector<std::string>{"-D", "-U"});
        if (split.first.size() == 0)
            continue;
        if (split.second.size() == 0)
            pending = split.first;
        else
            apply(split.first, split.second);
    }
    return out;
}

const std::vector<std::string>& cxx_source_extensions(void)
{
    static const auto out = std::vector<std::string>{
        ".c++", ".cpp", ".cxx", ".cc", ".C"
    };
    return out;
}

const std::vector<std::string>& cxx_header_extensions(void)
{
    static const auto out = std::vector<std::string>{
        ".h++", ".hpp", ".hxx", ".hh", ".h"
    };
    return out;
}

/* What to run to build C++ for the machine a CROSS_COMPILE named, or
 * for this one when it named nothing.
 *
 * A cross toolchain doesn't come with a CXX pointing at it: that
 * variable belongs to whoever runs make and it names the one compiler
 * this machine has.  So a cross build has to name the program
 * outright, which it can do because every program in a toolchain is
 * called the same thing with the same prefix on the front -- that's
 * what a CROSS_COMPILE is, and it's the spelling kbuild has used for
 * as long as anybody has been doing this. */
std::string language_cxx::default_compiler_command(const context::ptr& ctx) const
{
    if (ctx->cross_compile.size() > 0)
        return ctx->cross_compile + "g++ -x c++ ${CXXFLAGS}";

    return "${CXX} -x c++ ${CXXFLAGS}";
}

std::string language_cxx::default_linker_command(const context::ptr& ctx) const
{
    if (ctx->cross_compile.size() > 0)
        return ctx->cross_compile + "g++ ${LDFLAGS} ${CXXFLAGS}";

    return "${CXX} ${LDFLAGS} ${CXXFLAGS}";
}

language_cxx* language_cxx::clone(void) const
{
    return new language_cxx(this->list_compile_opts(),
                            this->list_link_opts());
}

bool language_cxx::can_process(const context::ptr& ctx) const
{
    return language::all_sources_match(ctx, cxx_source_extensions());
}

bool language_cxx::owns_source(const std::string& path) const
{
    for (const auto& extension: cxx_source_extensions())
        if (string_utils::has_extension(path, extension))
            return true;
    return false;
}

bool language_cxx::keeps_source(const std::string& path) const
{
    return this->owns_source(path)
        || string_utils::has_extension(path, ".c");
}

language_cxx::behind_languages
language_cxx::languages_behind_headers(const context::ptr& ctx) const
{
    auto out = behind_languages();
    out.target = this;

    for (const auto& extension: cxx_header_source_extensions()) {
        /* A name to ask about rather than a bare ending, which
         * has_extension() doesn't count as having one. */
        auto example = "source" + extension;

        /* Every ending belongs to at most one language, so this is
         * the same answer whatever order LANGUAGES named them in.  The
         * target's own language is asked first, and more generously:
         * it keeps what it can compile, not just what it owns. */
        auto owner = static_cast<const language_cxx*>(this);
        if (this->keeps_source(example) == false) {
            for (const auto& l: ctx->languages) {
                auto c = dynamic_cast<const language_cxx*>(l.get());
                if (c == nullptr || c->name() == this->name())
                    continue;
                if (c->owns_source(example) == true) {
                    owner = c;
                    break;
                }
            }
        }

        out[extension] = owner;
    }

    return out;
}

language_cxx::shared_target language_cxx::is_shared_target(const context::ptr& ctx) const
{
    switch (ctx->type) {
        case context_type::LIBRARY:
            return shared_target::TRUE;

        case context_type::BINARY:
            return shared_target:: FALSE;

        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::SOURCE:
        case context_type::TEST:
        case context_type::HEADER:
        case context_type::PHONY:
            break;
    }

    std::cerr << "language_cxx: Internal error in is_shared_target()" << std::endl;
    abort();
}

std::string language_cxx::archiver_command(const context::ptr& ctx) const
{
    if (ctx->cross_compile.size() > 0)
        return ctx->cross_compile + "ar";

    return "${AR}";
}

/* An option that reaches the command line and isn't in the hash is
 * an option make can't see change: the hash names the directory the
 * output goes in, and a new directory is the only thing that makes the
 * link run again, because make never reruns a recipe merely because
 * its text moved.  So everything pconfigure adds to the link line goes
 * in, not just what the Configfile spelled as LINKOPTS -- the "-l" a
 * DEPLIBS turns into, the "-L" for this project's own libraries, and
 * the PREFIX and LIBDIR that the rpaths are built from.  Leaving those
 * out is how a DEPLIBS that went away left the binary still asking for
 * the library, and how a new PREFIX left "make install" copying a
 * program that looked for its libraries under the old one. */
std::string language_cxx::hash_link_options(const context::ptr& ctx) const
{
    return hash_options(
        std::vector<std::string>{this->linker_command(ctx)}
        + this->clopts()
        + ctx->clopts()
        + added_link_options(ctx, spelling::FROM_PROJECT)
        + std::vector<std::string>{
            "prefix:" + ctx->prefix,
            "lib_dir:" + ctx->unbased(ctx->lib_dir),
        }
    );
}

/* The same goes for an object, so this hashes the compile line
 * itself rather than the COMPILEOPTS it was built from: the
 * "-D__PCONFIGURE__PREFIX" and "-D__PCONFIGURE__LIBEXEC" that
 * compile_options() adds name the install prefix, and with only the
 * Configfile's options in the hash a new PREFIX left every object
 * where it was, with the old prefix compiled into it.
 *
 * Both lines are hashed as the project itself would spell them,
 * though, not as the Makefile does.  A subproject is configured from
 * the top of a run and configured on its own, and the manual promises
 * the two share what they build: they agree on where each object
 * goes, and only the hash was left to tell them apart.  From the top
 * every path pconfigure roots at the subproject starts with its
 * directory -- "-Isub/include", "-Lsub/lib" -- and from inside it
 * doesn't, so hashing the line as it stood named one object two ways.
 * Each side then found the other's object missing and built its own,
 * and an edit to one source was compiled, linked and copied into
 * place twice, once by each.
 *
 * What gets respelled is only what pconfigure rooted there, and that
 * is decided where the rooting is done rather than by looking for the
 * directory on the finished line.  Taking it back off wherever it
 * started a word used to take it off what the project wrote, too: in
 * a subproject "sub", -DWHERE='"sub/marine"' hashed the same as
 * -DWHERE='"marine"', and the LINKOPTS, which go into the link's hash
 * before they are rooted at all, had "-Lsub/pre" (sub/sub/pre from
 * the top) hash the same as "-Lpre".  Changing one into the other
 * named the same object or link directory, which make found up to
 * date, and the program went on being the old one.
 *
 * Nothing that tells two objects apart is lost by respelling.  Every
 * project's objects are under that project's own object directory,
 * so the directory taken off here is one the object's path still
 * carries.  The dependency fragments beside an object, by contrast,
 * are deliberately one per run -- each names its paths from where its
 * own make stands -- so the hash that tells those apart goes on
 * hashing the spelling as it is. */
std::string language_cxx::hash_compile_options(const context::ptr& ctx,
                                               const context::ptr& child)
                                               const
{
    return hash_options(
        std::vector<std::string>{this->compiler_command(child)}
        + compile_options(ctx, child, spelling::FROM_PROJECT)
    );
}

/* The link options pconfigure adds on top of what the Configfile
 * said.  Both the link line and the hash naming its directory are
 * built from these, so the two can't drift apart.  They come as two
 * halves because the link line doesn't keep them together: the lib
 * directory goes ahead of the Configfile's LINKOPTS and the DEPLIBS
 * after them (link_objects() says why). */
std::vector<std::string>
language_cxx::lib_dir_link_options(const context::ptr& ctx,
                                   spelling spelled) const
{
    /* The lib directory is only worth searching when something in
     * this project builds a library into it.  A project that builds
     * none never creates the directory, and a linker handed a "-L"
     * naming one that isn't there warns about it -- a warning about a
     * directory pconfigure invented, which leaves whoever reads it
     * with nothing to go fix. */
    auto lib_dir = (spelled == spelling::FROM_PROJECT)
        ? ctx->unbased(ctx->lib_dir)
        : ctx->lib_dir;
    return ctx->lib_dir_built
        ? std::vector<std::string>{"-L" + lib_dir}
        : std::vector<std::string>();
}

std::vector<std::string>
language_cxx::dep_lib_link_options(const context::ptr& ctx) const
{
    return vector_util::map(ctx->dep_libs, [](std::string dl){ return "-l" + dl; });
}

std::vector<std::string>
language_cxx::added_link_options(const context::ptr& ctx,
                                 spelling spelled) const
{
    return lib_dir_link_options(ctx, spelled) + dep_lib_link_options(ctx);
}

/* The hash is the whole of what tells two option lists apart, since
 * it alone names the object or the link directory, and make never
 * reruns a recipe because its text changed.  Two lists that hash alike
 * therefore share one output, and switching from one to the other
 * leaves whatever the first built in place.  So the hash is kept as
 * wide as std::hash is, which is 64 bits on a 64-bit host.  It used to
 * be folded into 32, and at 32 bits the birthday bound puts a
 * colliding pair among a few tens of thousands of values of a single
 * "-D" -- few enough that a search finds one in well under a second.
 *
 * Widening it rather than also recording the full option text beside
 * each output is a trade: 64 bits makes a collision something no
 * project will meet, where a record would make one harmless, but the
 * record is another file per object for make to read on every run. */
std::string language_cxx::hash_options(const std::vector<std::string>& opts) const
{
    std::hash<std::string> hash_fn;
    uint64_t seed = 5831;
    for (const auto& opt: opts)
        seed ^= hash_fn(opt) + 0x9e3779b97f4a7c15ULL
              + (seed << 6) + (seed >> 2);
    return std::to_string(seed);
}

std::vector<makefile::target::ptr> language_cxx::targets(const context::ptr& ctx) const
{
    /* We can only support some sorts of targets, it doesn't make sense to do a
     * top-level build for any others. */
    switch (ctx->type) {
        case context_type::LIBRARY:
        case context_type::BINARY:
        {
            auto objects = std::vector<target::ptr>();
            auto already_processed = std::vector<std::string>();
            auto tests = std::vector<makefile::target::ptr>();

            /* The pieces of Makefile that say what this target's
             * sources depend on, which is what an AUTORECONFIGURE
             * project gets instead of "objects" above. */
            auto fragments = std::vector<makefile::target::ptr>();
            auto behind = languages_behind_headers(ctx);
            for (const auto& child: ctx->children) {
                auto is_shared = (ctx->type == context_type::BINARY)
                        ? shared_target::FALSE
                        : shared_target::TRUE;

                switch (child->type) {
                case context_type::SOURCE:
                {
                    /* A project that works its dependencies out during
                     * the build has nothing to walk here: what this
                     * source turns into is written down by make, into
                     * a file that make includes.  The compile rule and
                     * the objects behind the headers arrive from
                     * there. */
                    if (ctx->autoreconfigure == true) {
                        fragments.push_back(
                            deps_source(ctx, child, is_shared, behind));
                        break;
                    }

                    auto all_objects = compile_source(ctx,
                                                      child,
                                                      already_processed,
                                                      is_shared,
                                                      behind);

                    /* Checks for duplicate objects, to avoid double linking. */
                    auto compare_object = [](const target::ptr& a, const target::ptr& b) {
                        if (strcmp(a->path().c_str(), b->path().c_str()) != 0)
                            return false;

                        /* FIXME: We shouldn't just compare hashes to ensure these
                         * are the same object, but should instead go and make sure
                         * they're exactly the same by comparing all the passed
                         * arguments. */
                        return true;
                    };

                    auto find_in_objects = [&](const target::ptr& object) {
                        for (const auto& in_objects: objects)
                            if (compare_object(in_objects, object) == true)
                                return true;
                        return false;
                    };

                    for (const auto& object: all_objects)
                        if (find_in_objects(object) == false)
                            objects = objects + std::vector<target::ptr>{object};
                    break;
                }

                case context_type::TEST:
                {
                    auto l = pick_language(ctx->languages, child);
                    auto filtered_child = [&]() -> context::ptr
                        {
                            if (l->name() == this->name())
                                return child;

                            return child->without_clopts(ctx);
                        }();
                    tests = tests + l->targets(filtered_child);
                    break;
                }

                case context_type::DEFAULT:
                case context_type::BINARY:
                case context_type::LIBRARY:
                case context_type::GENERATE:
                case context_type::HEADER:
                case context_type::PHONY:
                    std::cerr << "Unable to process " << ctx->cmd->debug() << "\n";
                    abort();
                    break;
                }

                if (child->type != context_type::SOURCE)
                    continue;
            }

            auto link = link_objects(ctx, objects);
            return vector_util::map(objects + link,
                                    [](const target::ptr& t) -> makefile::target::ptr
                                    {
                                        return t->generate_makefile_target();
                                    })
                   + fragments
                   + tests;
        }

        case context_type::TEST:
        {
            auto child_ctx = ctx->dup(context_type::BINARY);
            child_ctx->bin_dir = ctx->obj_dir + "/" + ctx->unbased(ctx->check_dir);

            /* A test program is run out of the build tree and never
             * installed, which is what a TESTEXECS is too, so it's
             * built the way one is: the local link and nothing else.
             * This used to build it as an ordinary BINARIES and then
             * filter out whatever was marked as installing -- but only
             * the copy into $(DESTDIR) is, and the link it copies
             * from, the one with the PREFIX's rpath, stayed a
             * prerequisite of the check.  Every "make check" linked
             * each compiled test twice, once into a file nothing
             * read.  Saying so up front also keeps the link steps
             * the objects' dependency fragments name in step with the
             * ones that exist, since both are asked the same
             * question. */
            child_ctx->install = false;
            auto bin_targets =
                vector_util::map(targets(child_ctx),
                                 [](const makefile::target::ptr& t)
                                 {
                                     return t->without(makefile::global_targets::ALL);
                                 });
            /* The program this test is attached to is whatever opened
             * the target above it -- the same answer bash.c++ gives a
             * BASH test.  It is not anything out of bin_targets: those
             * are the test's own compiled self, and the first of them
             * is an object file, which handed to the test as
             * $PTEST_BINARY was neither runnable nor in $BINDIR, and as
             * the prerequisite meant a rebuilt program never made the
             * test run again.
             *
             * A test under a PHONY has nothing it's testing, so
             * there's no program to wait for and none to hand it.
             * Everywhere else this is the thing the test
             * exercises. */
            auto bin_name = ctx->test_binary;
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
             * arguments, the second of which it has never heard of.  So it
             * is quoted, and make expanding the $(abspath) from inside the
             * quotes is exactly what's wanted, since make has no idea they
             * are there.  What single quotes still can't carry is a checkout
             * path with a single quote in it, since make puts that in after
             * the quoting was decided.
             */
            auto srcdir = string_utils::quoted("$(abspath " + ctx->src_path + ".)");

            /* Scratch that does not get collected, named after the test
             * and sitting beside the test's own compiled self under
             * $OBJDIR.
             *
             * Beside the test rather than in the check directory, which
             * is the obvious place and is wrong: "make report" walks a
             * check directory with find and reads every file it lands
             * on as a result tarball, so a disk image left in there is
             * handed to tar as though it were one test's verdict.
             * $OBJDIR is the other directory a test already has to
             * itself, it is on the same volume as the tree -- which is
             * what keeps a copy-on-write clone of a fixture cheap --
             * and "make clean" already removes it. */
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
                "language_cxx::targets() CHECK"
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

        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::SOURCE:
        case context_type::HEADER:
        case context_type::PHONY:
            std::cerr
                << "Unable to build C++ for unsupported context type "
                << std::to_string(ctx->type)
                << "\n";
            std::cerr << std::to_string(ctx->cmd->debug()) << "\n";
            abort();
            break;
    }

    std::cerr << "language_cxx::targets(): Unknown context type\n" << std::endl;
    abort();
    return {};
}

std::vector<std::string>
language_cxx::find_files_for_header(const std::string& full_header_path) const
{
    return cxx_sources_for_header(full_header_path);
}

const std::vector<std::string>& cxx_header_source_extensions(void)
{
    /* A header and the source that implements it are the same name
     * with a different ending, and that's the only thing saying the
     * two go together -- nobody writes it down.  Everything that
     * exists gets built, because a project that keeps both a "foo.c"
     * and a "foo.c++" next to "foo.h" meant to have both.
     *
     * The list of endings tried here isn't quite the list of names a
     * C++ source goes by.  ".c" is in it even though it isn't one of
     * them, because this is also how the C language finds the source
     * behind a header it saw included -- it inherits this function.
     * Finding a file is not deciding what it is, though: each one is
     * compiled as whatever its own ending says, which is
     * languages_behind_headers()' business.
     *
     * ".C" is out of it even though it is one of them, because it
     * differs from ".c" only in case: on a filesystem that doesn't
     * care about that, guessing both hands back one file twice under
     * two names, and it gets compiled and linked in twice.  A project
     * that spells its C++ ".C" can still say so in a SOURCES line,
     * where nobody has to guess. */
    static const auto out = std::vector<std::string>{
        ".c++", ".cpp", ".cxx", ".cc", ".c"
    };
    return out;
}

std::vector<std::string>
cxx_sources_for_header(const std::string& full_header_path)
{
    std::vector<std::string> out;

    for (const auto& header: cxx_header_extensions()) {
        if (string_utils::has_extension(full_header_path, header) == false)
            continue;

        auto stem = full_header_path.substr(
            0, full_header_path.size() - header.size());

        for (const auto& source: cxx_header_source_extensions()) {
            auto f = stem + source;
            if (access(f.c_str(), R_OK) == 0)
                out.push_back(f);
        }
    }

    return out;
}

language_cxx::link_target::link_target(const std::string& target_path,
                                       const std::vector<target::ptr>& objects,
                                       const std::vector<target::ptr>& additional_deps,
                                       const install_target& install,
                                       const shared_target& shared,
                                       const std::vector<std::string>& comments,
                                       const std::vector<std::string>& opts,
                                       const context::ptr& ctx,
                                       const std::string linker_command,
                                       const std::string linker_pretty,
                                       const std::string link_inputs_path)
: _target_path(target_path),
  _objects(objects),
  _additional_deps(additional_deps),
  _install(install),
  _shared(shared),
  _comments(comments),
  _opts(opts),
  _ctx(ctx),
  _linker_command(linker_command),
  _linker_pretty(linker_pretty),
  _link_inputs_path(link_inputs_path)
{
}

makefile::target::ptr
language_cxx::link_target::generate_makefile_target(void) const
{
    auto deps = vector_util::map(_objects + _additional_deps,
                                 [](const target::ptr& t){
                                    return t->generate_makefile_target();
                                 });
    auto target2name = [](const target::ptr& t){ return t->path(); };

    /* The hash of this link's inputs, from link_objects().  It rides
     * the rule as a prerequisite so that an input leaving the link --
     * which changes the file but makes nothing that remains newer --
     * still runs the link again.  The recipe below filters
     * non-%.o prerequisites out of the link line, so the file adds
     * nothing to what gets linked. */
    if (_link_inputs_path.size() > 0)
        deps.push_back(std::make_shared<makefile::target>(_link_inputs_path));

    /* The files a LINKOPTS has the linker read are inputs to the link
     * as much as the objects are: a version script decides what a
     * library exports, and a prebuilt archive or object is copied
     * into whatever links it.  A file this build makes was already
     * waited on, through needs() matching it up with the rule that
     * makes it, but one that was only ever on disk -- which is what
     * a version script or a vendored archive usually is -- was a
     * prerequisite of nothing, and editing it relinked nothing.
     *
     * Through "$(wildcard)" for the reason a source is in
     * deps_source(): a file that has gone away since pconfigure ran
     * is the linker's to complain about, naming the file, rather than
     * make's "No rule to make target", which names no Configfile line
     * at all.  It also leaves a file this build does make to the rule
     * that makes it, since $(wildcard) hands make back the bare
     * name. */
    auto input_files = link_input_files(_opts);
    for (const auto& file: input_files)
        deps.push_back(std::make_shared<makefile::target>(
                           "$(wildcard "
                           + makefile::function_argument(file)
                           + ")"));

    /* Whether what comes out of this link is a Mach-O.  That's a
     * question about the machine being built for rather than the one
     * doing the building, and the two are the same machine right up
     * until a CROSS_COMPILE says they aren't.
     *
     * Everything below that Apple's linker understands and nobody
     * else's does hangs off this.  Getting it wrong isn't subtle in
     * one direction -- "-install_name" is not an option GNU ld has,
     * so a cross-linked shared library stops dead -- and is very
     * subtle in the other, where "@loader_path" is accepted as a
     * perfectly good literal rpath that means nothing anywhere the
     * binary will actually run. */
#ifdef __APPLE__
    const auto mach_o = _ctx->cross_compile.size() == 0;
#else
    const auto mach_o = false;
#endif

#ifdef __APPLE__
    /* Where the plist an ENTITLEMENTS names actually lives: it's
     * written relative to the project that asked for it, the same as
     * everything else in that project's Configfile. */
    auto entitlements = (mach_o == false || _ctx->entitlements.size() == 0)
        ? std::string()
        : _ctx->base + _ctx->entitlements;

    /* Changing what a binary is allowed to do has to re-sign it, and
     * signing only happens as part of a link, so the plist is an
     * input to the link like any of the objects are. */
    if (entitlements.size() > 0)
        deps.push_back(std::make_shared<makefile::target>(entitlements));
#endif

    /* The name this library goes by once it's built, which is the
     * file's own name and nothing more.  A LIBRARIES line may put a
     * directory in front of it ("sub/libfoo.so") or spell it with a
     * "./", and either way that says where the file goes under lib/
     * rather than what it's called.  Whatever goes here is copied
     * into every consumer's NEEDED (or load command, on Mach-O), and
     * the dynamic loader reads one with a '/' in it as a path from
     * the directory the program was started in instead of a name to
     * look up along its runpath -- so a consumer would only start
     * from one directory.  The path is normalized first so that a
     * ".." can't leave anything but a file name behind. */
    auto soname = [&](void) -> std::string
        {
            auto path = file_utils::normalize_path(_ctx->cmd->data());
            auto slash = path.rfind('/');
            if (slash == std::string::npos)
                return path;
            return path.substr(slash + 1);
        }();

    auto shared = [&](void) -> std::string
        {
            switch (_shared) {
            case shared_target::TRUE:
                if (mach_o == true)
                    return " -shared -Wl,-install_name,@rpath/" + soname;
                /* Without an ELF soname, a consumer's NEEDED entry
                 * doesn't get this library's name -- it gets whatever
                 * path "-l" happened to resolve to when THAT consumer
                 * was linked (here, literally "lib/libgladefs.a"),
                 * because that's the only string an ld with no soname
                 * to prefer has to record.  That string is a build-time
                 * relative path, not a name: it only resolves again if
                 * the consumer is later run from the one directory it
                 * was linked from, which is exactly as fragile as it
                 * sounds. -install_name is the Mach-O spelling of the
                 * same idea just above; -soname is ELF's. */
                return " -shared -Wl,-soname," + soname;
            case shared_target::FALSE:
                return "";
            }

            abort();
            return "";
        }();

    auto dotdot = [](std::string path) -> std::string
        {
            auto out = std::string("../");
            for (const auto& c: path)
                if (c == '/')
                    out = out + "../";
            return out;
        };
    /* Where a binary looks for the shared libraries it was linked
     * against when it's run.  Once installed everything lives in one
     * place; before that it's still spread across the build tree,
     * which for a project with subprojects means more than one
     * directory. */
    auto local_rpath = [&](const std::string& dir) -> std::string
        {
            /* How far the file being linked is from the top of its
             * own project.  That's the directory it gets copied into
             * plus whatever directories its own name has in it -- a
             * LIBEXEC called "sub/tool" lands one deeper than one
             * called "tool", and has one further to walk back. */
            auto output_dir = [&](void) -> std::string
                {
                    auto dir = (_ctx->type == context_type::LIBRARY)
                        ? _ctx->unbased(_ctx->lib_dir)
                        : _ctx->unbased(_ctx->bin_dir);

                    auto name = _ctx->cmd->data();
                    auto slash = name.find_last_of('/');
                    if (slash != std::string::npos)
                        dir += "/" + name.substr(0, slash);

                    return dir;
                }();

            auto from_output = dotdot(output_dir);

            /* Relative to whatever's being loaded rather than to the
             * program doing the loading: a library that a subproject
             * built sits at a different depth than the binary that
             * ends up linking it, and only the library knows how far
             * it is from the libraries it needs itself.  This is what
             * ELF has always done here; macOS needed asking. */
            if (mach_o == true)
                return "-Wl,-rpath,@loader_path/" + from_output + dir;
            return "-Wl,-rpath,\\$$ORIGIN/" + from_output + dir;
        };

    auto rpaths = [&](void) -> std::vector<std::string>
        {
            switch (_install) {
            case install_target::TRUE:
            {
                auto out = std::vector<std::string>{
                    "-Wl,-rpath," + _ctx->installed(_ctx->lib_dir)
                };

                /* A LIBRARIES name with a directory in it installs
                 * into that directory under the lib directory, and a
                 * consumer finds it at build time with a "-L" into
                 * the same place in the build tree.  Its soname is
                 * just the file's name, so once installed the only
                 * way the loader finds it is a runpath entry for that
                 * directory too.  Every other "-L" is left alone, the
                 * same as before: one into a subproject or outside
                 * this project says nothing about where its libraries
                 * end up installed. */
                auto lib_dir = canonical_dir(_ctx->lib_dir) + "/";
                for (const auto& raw: link_dirs(_opts)) {
                    auto dir = canonical_dir(raw);
                    if (dir.compare(0, lib_dir.size(), lib_dir) != 0)
                        continue;

                    /* "-Llib/sub" twice, or once as "-L./lib/sub", is
                     * still the one directory to look in. */
                    auto rpath = "-Wl,-rpath,"
                        + _ctx->installed(_ctx->lib_dir)
                        + "/" + dir.substr(lib_dir.size());
                    if (std::find(out.begin(), out.end(), rpath) == out.end())
                        out.push_back(rpath);
                }

                return out;
            }

            case install_target::FALSE:
            {
                auto out = std::vector<std::string>{
                    local_rpath(_ctx->unbased(_ctx->lib_dir))
                };

                /* A "-L" pointing somewhere else in this build is a
                 * library that came from a subproject, and it hasn't
                 * been installed yet either.  Directories outside
                 * this project are left alone: working out how to get
                 * back to them from here isn't something this knows
                 * how to do. */
                for (const auto& raw: link_dirs(_opts)) {
                    auto dir = relative_to_here(raw);

                    if (dir == _ctx->lib_dir)
                        continue;
                    if (dir.size() == 0 || dir[0] == '/')
                        continue;
                    if (_ctx->base.size() > 0
                        && dir.compare(0, _ctx->base.size(), _ctx->base) != 0)
                        continue;

                    out.push_back(local_rpath(_ctx->unbased(dir)));
                }

                return out;
            }
            }

            abort();
            return {};
        }();

    auto rpath_suffix = std::string();
    for (const auto& rpath: rpaths)
        if (std::find(_opts.begin(), _opts.end(), rpath) == _opts.end())
            rpath_suffix += " " + rpath;

    /* "-framework Foo" is Apple ld64 syntax with no ELF equivalent, so
     * it only ever belongs on the link line when this link is actually
     * producing a Mach-O -- the same "mach_o" check that gates
     * codesigning below.  FRAMEWORKS is parsed and stored on every
     * platform (see command_processor.c++); this is the one place
     * that turns it into anything. */
    auto framework_suffix = std::string();
    if (mach_o == true)
        for (const auto& framework: _ctx->frameworks)
            framework_suffix += " -framework " + framework;

    /* What gets linked.  A project that worked its dependencies out
     * here knows the list; one that leaves it to the build does not,
     * and asks make for whatever turned up as a prerequisite -- which
     * is the same list, arrived at by reading the fragments in the
     * order pconfigure would have walked them.  "$^" drops the
     * repeats, which is the other half of what the walk did by
     * hand. */
    auto object_args = _ctx->autoreconfigure
        ? std::string("$(filter %.o,$^)")
        : vector_util::join(vector_util::map(_objects, target2name), " ");

    /* ... except for a prebuilt object a LINKOPTS named, which is a
     * prerequisite now as well, and is on the link line already as
     * the word it was written as.  A second copy of it is every
     * symbol in it defined twice.
     *
     * The space before the comma is for needs(), which reads this
     * recipe a shell word at a time and takes any word with a '/' in
     * it for a file the link wants.  With the paths standing as words
     * of their own that is just the files themselves, which the
     * LINKOPTS words already ask for, rather than a path glued onto
     * the make syntax after it.  To make, the space is just one more
     * separator between the filter's patterns. */
    if (_ctx->autoreconfigure && input_files.size() > 0)
        object_args = "$(filter-out "
            + makefile::function_argument(vector_util::join(input_files, " "))
            + " ," + object_args + ")";

    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        _linker_command
          + " -o" + _target_path
          + " " + object_args
          + " " + vector_util::join(_opts, " ")
          + " " + shared
          + rpath_suffix
          + framework_suffix
    };

#ifdef __APPLE__
    /* On macOS the kernel refuses to exec (or dlopen) a Mach-O whose code
     * signature is invalid, killing the process with SIGKILL.  The linker
     * usually adds an ad-hoc signature, but it can be left stale/invalid when
     * we rewrite the binary (e.g. the install_name_tool-style rpath tweaks
     * above), so re-sign the freshly-linked output ad-hoc to be safe.
     *
     * The signature is also the only place macOS looks to find out what
     * a binary is allowed to do, so anything ENTITLEMENTS asked for has
     * to be named here: signing without it doesn't leave the previous
     * entitlements alone, it drops them.
     *
     * codesign is chatty on success ("<file>: replacing existing signature"),
     * so on non-verbose runs swallow its output but still surface it if the
     * signing actually fails. */
    auto sign = "codesign --force --sign -"
        + (entitlements.size() == 0
           ? std::string()
           : " --entitlements " + entitlements)
        + " " + _target_path;
    if (_ctx->verbose == false)
        sign = "out=$$(" + sign + " 2>&1) || { echo \"$$out\"; exit 1; }";

    /* A signature is a Mach-O idea, and the linker on the other end of
     * this isn't always one that makes Mach-Os: point a CROSS_COMPILE
     * at a toolchain for somebody else's machine and what lands here
     * is an ELF.  codesign doesn't refuse those, which is the trouble
     * -- it quietly signs them "generic", hanging an ad-hoc signature
     * off the file in extended attributes that means nothing to the
     * machine the thing is going to run on, accepting --entitlements
     * while ignoring it, and failing outright on a file that arrived
     * carrying attributes of its own.  So ask what was actually linked
     * before signing it, and leave a foreign object the way its own
     * linker left it.  file(1) ships with the OS the same way codesign
     * does, and every Mach-O it knows about -- thin, fat, library,
     * object -- it names starting with the same word. */
    if (mach_o == true)
        cmds.push_back("case $$(/usr/bin/file -b " + _target_path
                     + ") in Mach-O*) " + sign + " ;; esac");
#endif

    auto global = std::vector<makefile::global_targets>{
        makefile::global_targets::CLEAN,
    };

    return std::make_shared<makefile::target>(
        _target_path,
        _linker_pretty + "\t" + _ctx->cmd->data(),
        deps,
        global,
        cmds,
        _comments);
}

language_cxx::archive_target::archive_target(const std::string& target_path,
                                             const std::vector<target::ptr>& objects,
                                             const std::vector<std::string>& comments,
                                             const context::ptr& ctx,
                                             const std::string archiver_command,
                                             const std::string archiver_pretty,
                                             const std::string link_inputs_path)
: _target_path(target_path),
  _objects(objects),
  _comments(comments),
  _ctx(ctx),
  _archiver_command(archiver_command),
  _archiver_pretty(archiver_pretty),
  _link_inputs_path(link_inputs_path)
{
}

makefile::target::ptr
language_cxx::archive_target::generate_makefile_target(void) const
{
    auto deps = vector_util::map(_objects,
                                 [](const target::ptr& t){
                                    return t->generate_makefile_target();
                                 });
    deps.push_back(std::make_shared<makefile::target>(_link_inputs_path));

    /* The same list a link_target would hand the linker, worked out
     * the same way; see there for why an AUTORECONFIGURE project asks
     * make for it. */
    auto object_args = _ctx->autoreconfigure
        ? std::string("$(filter %.o,$^)")
        : vector_util::join(vector_util::map(_objects,
                                             [](const target::ptr& t){
                                                 return t->path();
                                             }),
                            " ");

    /* "ar r" adds to whatever archive is already there rather than
     * replacing it, so an object that has left the library since the
     * last build would otherwise stay in it for good, still defining
     * whatever it used to define.  Starting from nothing every time
     * is what makes the archive say what the Configfile says now.
     * The "s" writes the symbol index, without which a linker can't
     * pull members out of the archive by the symbols they define. */
    /* An archive remembers each member by the last component of the
     * path it was added from, and every object pconfigure compiles is
     * called "<option hash>-shared.o" in a directory named after its
     * source.  Handed to "ar" as they are, every source built with the
     * same options becomes a member of the same name: linking still
     * works, since that goes through the symbol index, but "ar x"
     * leaves one file standing where there were several, "ar d" on a
     * name takes whichever comes first, and macOS's ranlib warns about
     * every archive with more than one source in it.
     *
     * So each object is linked into a directory of its own under the
     * name of the source it came from -- "one.c++.o" -- and archived
     * from there.  Two sources of the same name in different
     * directories still can't share one, so the later gets a number.
     * This happens in the recipe rather than here because under
     * AUTORECONFIGURE the list of objects is make's, not this
     * function's, and the directory is gone again once the archive is
     * written: it's a staging area, not something to keep in step. */
    auto stage = std::string("$(dir $@)members");
    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        "rm -rf $@ " + stage,
        "mkdir -p " + stage
          + " && members="
          + " && for o in " + object_args + "; do"
          +     " n=$$(basename $$(dirname $$o));"
          +     " m=" + stage + "/$$n.o; i=1;"
          +     " while test -e $$m; do"
          +         " i=$$(($$i + 1)); m=" + stage + "/$$n-$$i.o;"
          +     " done;"
          +     " ln -f $$o $$m 2>/dev/null || cp -f $$o $$m || exit 1;"
          +     " members=\"$$members $$m\";"
          + " done"
          + " && " + _archiver_command + " rcs $@ $$members",
        "rm -rf " + stage,
    };

    auto global = std::vector<makefile::global_targets>{
        makefile::global_targets::CLEAN,
    };

    return std::make_shared<makefile::target>(
        _target_path,
        _archiver_pretty + "\t" + _ctx->cmd->data(),
        deps,
        global,
        cmds,
        _comments);
}

language_cxx::compile_target::compile_target(const std::string& target_path,
                                             const std::string& main_source,
                                             const shared_target& shared,
                                             const std::vector<std::string>& comments,
                                             const std::vector<std::string>& opts,
                                             const context::ptr& ctx,
                                             const std::vector<target::ptr>& hd,
                                             const std::string compiler_command,
                                             const std::string compiler_pretty)
: _target_path(target_path),
  _main_source(main_source),
  _shared(shared),
  _comments(comments),
  _opts(opts),
  _ctx(ctx),
  _header_deps(hd),
  _compiler_command(compiler_command),
  _compiler_pretty(compiler_pretty)
{
}

makefile::target::ptr
language_cxx::compile_target::generate_makefile_target(void) const
{
    auto deps = std::vector<makefile::target::ptr>{
      std::make_shared<makefile::target>(_main_source)
    } + vector_util::map(_header_deps,
                         [](target::ptr t)
                         {
                             return t->generate_makefile_target();
                         });

    auto pic = [&]() -> std::string
        {
            switch (_shared) {
                case shared_target::FALSE:
                    return "";
                case shared_target::TRUE:
                    return " -fPIC";
            }

            abort();
            return "";
        }();

    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        _compiler_command
          + " " + vector_util::join(_opts, " ")
          + " -c " + _main_source
          + " -o " + _target_path
          + pic
    };

    auto global = std::vector<makefile::global_targets>{
        makefile::global_targets::CLEAN,
    };

    return std::make_shared<makefile::target>(
        _target_path,
        _compiler_pretty + "\t" + _ctx->cmd->data(),
        deps,
        global,
        cmds,
        _comments);
}

language_cxx::cp_target::cp_target(const std::string& target_path,
                                   const std::string& pretty_path,
                                   const target::ptr& source,
                                   const install_target& install,
                                   const std::string& install_mode,
                                   const std::vector<std::string> comments,
                                   const makefile::target::ptr& record)
: _target_path(target_path),
  _pretty_path(pretty_path),
  _source(source),
  _install(install),
  _install_mode(install_mode),
  _comments(comments),
  _record(record)
{
}

makefile::target::ptr
language_cxx::cp_target::generate_makefile_target(void) const
{
    auto deps = vector_util::make(_source->generate_makefile_target());
    deps.push_back(_record);

    auto cmds = copy_commands(_source->path(), _install, _install_mode);

    auto global = [&]()
        {
            switch (_install) {
                case install_target::FALSE:
                    return std::vector<makefile::global_targets>{
                        makefile::global_targets::CLEAN,
                        makefile::global_targets::ALL,
                    };
                case install_target::TRUE:
                    return std::vector<makefile::global_targets>{
                        makefile::global_targets::UNINSTALL,
                        makefile::global_targets::INSTALL,
                    };
            }

            abort();
            return std::vector<makefile::global_targets>();
        }();


    return std::make_shared<makefile::target>(
        _target_path,
        std::string("CP\t") + _pretty_path,
        deps,
        global,
        cmds,
        _comments);
}

std::vector<std::string>
language_cxx::cp_target::copy_commands(const std::string& source_path,
                                       const install_target& install,
                                       const std::string& install_mode)
{
    /* Copied next to where it goes and then renamed over it, rather
     * than written straight through the file that's already there.
     *
     * A rebuild replaces a program or a library that something may
     * well have open, and "cp" opens the destination and truncates it
     * -- so what used to be there and what is there now are one file,
     * and everything with it mapped is running against pages that
     * have changed underneath it.  On macOS the kernel has already
     * checked that file's code signature and remembered the answer
     * against that file, so the next thing to exec or load it dies of
     * SIGKILL with nothing printed at all.  A rename leaves the old
     * file alone for whoever still has it, and gives the new one its
     * own identity to be checked. */
    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
#if defined(__gnu_linux__)
        "cp --reflink=auto -f " + source_path + " $@.tmp",
#else
        "cp -f " + source_path + " $@.tmp",
#endif
    };

    /* An installed copy gets a fixed mode before it's renamed into
     * place, as it would from "install -m".  A "cp" carries over the
     * mode of what it copies, which is whatever the builder's umask
     * left it with: a program or a shared library only came out 0755
     * because its install flavour happens to be linked during the
     * install, under that umask instead, and a static archive -- which
     * has the one flavour, made during the build -- went in under
     * "umask 077" as a file nobody else could link against.  The build
     * tree's copy is the builder's, and keeps the mode it was made
     * with. */
    if (install == install_target::TRUE)
        cmds.push_back("chmod " + install_mode + " $@.tmp");

    cmds.push_back("mv -f $@.tmp $@");
    return cmds;
}

language_cxx::header_target::header_target(const std::string& path)
: _path(path)
{
}

makefile::target::ptr
language_cxx::header_target::generate_makefile_target(void) const
{
    /* Only ever a prerequisite, and a path the scan found rather than
     * one anybody wrote down: a header called "my extra.h" or one
     * under a "-I" with an escaped space in it is a real file, and the
     * object has to wait on that file rather than on the halves make
     * would split it into.  compile_source() has already refused the
     * names make has no spelling for. */
    return std::make_shared<makefile::target>(makefile::prerequisite(_path));
}

std::string language_cxx::output_dir(const context::ptr& ctx) const
{
    switch (ctx->type) {
    case context_type::BINARY:
        return ctx->bin_dir;
    case context_type::LIBRARY:
        return ctx->lib_dir;

    case context_type::DEFAULT:
    case context_type::GENERATE:
    case context_type::SOURCE:
    case context_type::TEST:
    case context_type::HEADER:
    case context_type::PHONY:
        break;
    }

    std::cerr << "language_cxx: Internal error in output_dir()\n";
    abort();
    return "";
}

/* The link options are hashed into this so that the same target
 * linked two ways lands in two directories rather than one of them
 * quietly overwriting the other. */
std::string language_cxx::link_dir(const context::ptr& ctx) const
{
    return ctx->obj_dir
        + "/" + ctx->unbased(output_dir(ctx))
        + "/" + ctx->cmd->data()
        + "/" + hash_link_options(ctx)
        + "/";
}

std::vector<language_cxx::target::ptr>
language_cxx::link_objects(const context::ptr& ctx,
                           const std::vector<language_cxx::target::ptr>& objects)
                           const
{
    auto shared_comments = std::vector<std::string>{
        std::to_string(ctx->cmd->debug()),
        "language_cxx::link_objects()",
    };
 
    auto bin_dir = output_dir(ctx);
    auto shared_link_dir = link_dir(ctx);

    /* The link's inputs, hashed into a file that rides the link rule
     * as a prerequisite.  GNU make relinks a target only when one of
     * its prerequisites is newer than it is -- never because one went
     * away -- so a source commented out of a SOURCES list took its
     * object off the rule's prerequisite list without giving make a
     * single reason to run the link again, and the binary went on
     * carrying the removed code.  A file that says what the inputs
     * are, and is rewritten only when that changes, is what brings
     * make around: it is written here, at configure time, so the
     * reconfigure rule's run of pconfigure refreshes it whenever the
     * input list moves -- the shape the vendored trees already get
     * for their configure options (project::write_configureopts(),
     * and the configureopts_file() prerequisite the configure rules
     * hang off in build_systems).  write_if_changed() leaves the file
     * alone when nothing changed, so a reconfigure that changes no
     * input relinks nothing, and the recipe's "filter %.o" below
     * keeps the file itself off the link line.
     *
     * What goes into the hash is each source as the Configfile named
     * it, along with the hash its object is named by, and then the
     * path of every object this link is handed.  The source names are
     * what a link input leaving the build takes off this list.  The
     * object hashes are what catch an edit that goes back: an object
     * is named by its compile line and its COMPILER, so trying
     * "-DX=2" on one source and then putting "-DX=1" back names the
     * very object the first build left, which is still there and
     * older than the program the build in between linked.  Neither
     * a per-source COMPILEOPTS nor a COMPILER goes into the name of
     * the directory this file sits in, so that stays the same either
     * way, and nothing on the rule was newer than that program: make
     * kept it, and its "2", under a Makefile that says "1".  With the
     * hashes in here, every change of compile options is a change to
     * this file, a revert included.
     *
     * The hashes come from the sources rather than from the objects
     * alone, because a project that works its dependencies out during
     * the build hands this nothing in "objects": what it links is
     * written down by make, and only the options it is compiled with
     * are known here.  Where there are objects, which includes the
     * ones built from behind a header and compiled the way their own
     * language says, their paths go in as well.  A change to the link
     * options, the target's COMPILEOPTS among them, was already an
     * input to the directory this file sits in, through
     * hash_link_options(). */
    auto link_inputs = std::vector<std::string>();
    for (const auto& child: ctx->children)
        if (child->type == context_type::SOURCE)
            link_inputs.push_back(ctx->unbased(child->src_dir)
                                  + "/" + child->cmd->data()
                                  + ":" + hash_compile_options(ctx, child));
    for (const auto& object: objects)
        link_inputs.push_back(ctx->unbased(object->path()));

    auto link_inputs_path = shared_link_dir + "link-inputs";
    /* Spelled the way the project spells them, for the same reason
     * the link directory's name is: both runs write this file into
     * that one directory, and two spellings of the same list would
     * have each configure look like a changed link to the other. */
    auto link_inputs_hash = this->hash_options(link_inputs);
    if (file_utils::write_configure_output(link_inputs_path,
                                           link_inputs_hash) == false) {
        std::cerr << "can't write '" << link_inputs_path << "': "
                  << strerror(errno) << "\n"
                  << "  this is where the inputs of '"
                  << ctx->cmd->data() << "'s link get hashed, which is\n"
                  << "  how a source leaving the link gets the link to"
                  << " run again\n";
        abort();
    }

    /* The copies out of the link directory need a record of their
     * own.  The directory is named by hash_link_options(), which
     * takes in the LINKOPTS and the target's COMPILEOPTS both, since
     * those go on the link line too -- so an edit that puts either
     * back to what an earlier build used goes back to the directory
     * that build linked in.  The link there is still on disk and up
     * to date, and it is older than the bin/ copy the build in
     * between made out of the other directory.  A copy is only redone
     * when what it copies is newer than it, so the program in bin/,
     * the library in lib/, and whatever "make install" puts under
     * $(DESTDIR) all went on being the in-between link under a
     * Makefile that says otherwise.  A record of the copy's recipe,
     * which names the directory it copies from, changes with every
     * move from one directory to another, a move back included; see
     * recipe_record().
     *
     * There is one record for both copies, kept under the name of the
     * one in the build tree: a "$(DESTDIR)" path is make's to expand
     * and has no place to be written at configure time, and the two
     * copies always come out of the same directory, so they always
     * move together.  The recipes are worked out by cp_target itself,
     * so the record says what the rules run. */
    auto copy_record = [&](const target::ptr& local_source,
                           const target::ptr& install_source,
                           const std::string& install_mode) {
        auto commands = cp_target::copy_commands(local_source->path(),
                                                 install_target::FALSE,
                                                 install_mode);
        if (ctx->install == true)
            commands = commands + cp_target::copy_commands(
                install_source->path(),
                install_target::TRUE,
                install_mode);
        return recipe_record(ctx, bin_dir + "/" + ctx->cmd->data(),
                             commands);
    };

    auto dedup_link_opts = [](std::vector<std::string> opts) {
        std::vector<std::string> tokens;
        for (const auto& opt : opts)
            for (const auto& tok: string_utils::shell_words(opt))
                tokens.push_back(tok);
        /* A library can be asked for as "-lfoo" or as "-l foo", and
         * the second spelling is two words that only mean something
         * together.  Deduplicating word by word would see every bare
         * "-l" after the first as a repeat and drop it, leaving its
         * library name behind as a bare word the linker then goes
         * looking for as a file.  So the two words are kept or dropped
         * as a unit, and keyed as the one-word spelling they mean, so
         * that "-l foo" and "-lfoo" count as the same request.  A "-l"
         * with nothing after it is passed along as written, for the
         * linker to complain about.
         *
         * Only a repeat that can't matter is dropped, though.  A
         * linker reads a static archive once, where it is named,
         * taking just the members that satisfy what is undefined at
         * that point, so naming one again later is how a link line
         * asks for a second look: "-la -lb -la" is the usual way to
         * link two archives that need each other, and dropping the
         * second "-la" leaves whatever libb wanted from liba
         * undefined.  What ld64 warns about, and what this filter is
         * for, is a library named twice with nothing in between that
         * could want anything from it: another library could, and so
         * could any word this doesn't recognize (a file, or a "-Wl,"
         * that passes the linker who knows what), but a "-L" or an
         * rpath only says where to look.  So the last library kept is
         * remembered until something that could need it comes along,
         * and a "-l" is dropped only when it names that one again. */
        std::set<std::string> seen_rpaths;
        std::string last_lib;
        std::vector<std::string> out;
        auto keep_lib = [&](const std::string& key) {
            if (key == last_lib)
                return false;
            last_lib = key;
            return true;
        };
        for (size_t i = 0; i < tokens.size(); ++i) {
            const auto& tok = tokens[i];
            if (tok == "-l" && i + 1 < tokens.size()) {
                if (keep_lib("-l" + tokens[i + 1])) {
                    out.push_back(tok);
                    out.push_back(tokens[i + 1]);
                }
                ++i;
                continue;
            }
            if (tok.substr(0, 2) == "-l" && tok != "-l") {
                if (keep_lib(tok))
                    out.push_back(tok);
                continue;
            }
            if (tok.substr(0, 11) == "-Wl,-rpath,") {
                if (seen_rpaths.insert(tok).second)
                    out.push_back(tok);
                continue;
            }
            if (tok == "-L" && i + 1 < tokens.size()) {
                out.push_back(tok);
                out.push_back(tokens[i + 1]);
                ++i;
                continue;
            }
            if (tok.substr(0, 2) != "-L")
                last_lib.clear();
            out.push_back(tok);
        }
        return out;
    };

    /* The lib directory goes ahead of every "-L" a LINKOPTS names,
     * because the linker searches its "-L" directories in the order
     * they're given and takes the first library of the right name it
     * finds.  A LINKOPTS directory is usually a pkg-config answer like
     * "-L/usr/local/lib", which is just where an earlier "make
     * install" of this same project left its old copies: searched
     * first, it handed the link yesterday's library in place of the
     * one this build had just made, and the program either failed to
     * link against it or, worse, linked and ran the stale code.  A
     * library this project builds is always the one it means. */
    auto all_opts = dedup_link_opts(
        lib_dir_link_options(ctx, spelling::FROM_HERE) +
        reroot_link_opts(link_opts() + ctx->link_opts, ctx->base) +
        dep_lib_link_options(ctx));

    /* Note that there's deliberately nothing here that turns a
     * DEPLIB into a prerequisite: the "-l" it adds to the link line
     * above is enough for that dependency to be worked out along with
     * everyone else's, which means a library that shows up on the
     * link line some other way gets one too. */
    auto additional_deps = std::vector<target::ptr>();

    /* A static archive is put together rather than linked, and it is
     * the same file whether it's headed for the tree or for $PREFIX:
     * there's no rpath to point anywhere, because an archive is never
     * loaded at all -- its members are copied into whatever links it.
     * So both copies come from the one archive.
     *
     * The objects are the position-independent ones every other
     * library is built from, which is what lets an archive be linked
     * into a shared library as well as into a program, and lets a
     * source that's in both a "libfoo.a" and a "libfoo.so" compile
     * once.
     *
     * Nothing here reads this library's LINKOPTS or DEPLIBS, because
     * an archive doesn't record what it needs.  A Configfile that
     * writes one directly under a "libfoo.a" was refused when the
     * line was read, which is where saying so can point at it;
     * anything left on the context is a language-wide default, and
     * belongs to whatever links the archive rather than to it.
     *
     * Its progress line says LD like any other library's, because
     * it's this target's link step that it names -- and because a
     * build log that changed what it calls a library's build along
     * with what the library is would be two changes at once. */
    if (ctx->is_static_archive()) {
        auto archive = std::make_shared<archive_target>(
            shared_link_dir + "archive",
            objects,
            shared_comments + std::vector<std::string>{"archive_target"},
            ctx,
            archiver_command(ctx),
            this->linker_pretty(),
            link_inputs_path
        );

        auto archive_record = copy_record(archive, archive, "0644");

        auto cp_local_archive = std::make_shared<cp_target>(
            bin_dir + "/" + ctx->cmd->data(),
            ctx->unbased(bin_dir) + "/" + ctx->cmd->data(),
            archive,
            language_cxx::install_target::FALSE,
            "0644",
            shared_comments + std::vector<std::string>{"cp_local_target"},
            archive_record
        );

        if (ctx->install == false)
            return {archive, cp_local_archive};

        /* The prefix goes on through installed(), like every other
         * install path, rather than being pasted on with a '/' either
         * side: that spelled the archive "$(DESTDIR)//usr/local/lib",
         * and "$(DESTDIR)///lib" under "PREFIX = /", a different make
         * target from the shared library installed right beside it. */
        auto archive_install_path =
            "$(DESTDIR)" + ctx->installed(bin_dir)
            + "/" + ctx->cmd->data();
        auto cp_install_archive = std::make_shared<cp_target>(
            archive_install_path,
            archive_install_path,
            archive,
            language_cxx::install_target::TRUE,
            "0644",
            shared_comments + std::vector<std::string>{"cp_install_target"},
            archive_record
        );

        return {archive, cp_install_archive, cp_local_archive};
    }

    /* There's actually two proper targets here: one which generates the link
     * that's targeted for installation, and one that generates the link that's
     * targeted for actual compulation. */
    auto install_target = std::make_shared<link_target>(
        shared_link_dir + "install",
        objects,
        additional_deps,
        language_cxx::install_target::TRUE,
        is_shared_target(ctx),
        shared_comments + std::vector<std::string>{"install_target"},
        all_opts,
        ctx,
        this->linker_command(ctx),
        this->linker_pretty(),
        link_inputs_path
    );

    auto local_target = std::make_shared<link_target>(
        shared_link_dir + "local",
        objects,
        additional_deps,
        language_cxx::install_target::FALSE,
        is_shared_target(ctx),
        shared_comments + std::vector<std::string>{"local_target"},
        all_opts,
        ctx,
        this->linker_command(ctx),
        this->linker_pretty(),
        link_inputs_path
    );

    /* In order to keep the local and install targets consistant with the
     * Makefile, we build the "copy" targets that depend on the generated
     * Makefile. */
    auto record = copy_record(local_target, install_target, "0755");

    auto install_path =
        "$(DESTDIR)" + ctx->installed(bin_dir)
        + "/" + ctx->cmd->data();
    auto cp_install_target = std::make_shared<cp_target>(
        install_path,
        install_path,
        install_target,
        language_cxx::install_target::TRUE,
        "0755",
        shared_comments + std::vector<std::string>{"cp_install_target"},
        record
    );

     auto cp_local_target = std::make_shared<cp_target>(
        bin_dir + "/" + ctx->cmd->data(),
        ctx->unbased(bin_dir) + "/" + ctx->cmd->data(),
        local_target,
        language_cxx::install_target::FALSE,
        "0755",
        shared_comments + std::vector<std::string>{"cp_local_target"},
        record
    );

    /* Here we return all the objects that were generated as part of this
     * linking step: that doesn't include the objects, they're expected to be
     * used elsewhere.  Targets that are never installed (TESTEXECs) don't need
     * the install-flavored link at all, as nothing depends on it. */
    if (ctx->install == false)
        return {local_target, cp_local_target};

    return {install_target, local_target, cp_install_target, cp_local_target};
}


std::vector<std::string>
language_cxx::compile_options(const context::ptr& ctx,
                              const context::ptr& child)
                              const
{
    return compile_options(ctx, child, spelling::FROM_HERE);
}

std::vector<std::string>
language_cxx::compile_options(const context::ptr& ctx,
                              const context::ptr& child,
                              spelling spelled)
                              const
{
    /* Spelled from the project, a path is what it would be from a run
     * inside it: the project's directory comes off the front, and a
     * SRCPATH that run would have been given stays on. */
    auto from = [&](const std::string& path) {
        return (spelled == spelling::FROM_PROJECT)
            ? child->unbased(path)
            : path;
    };

    /* A directory a Configfile names for the include search is
     * written from that Configfile's directory, by somebody who only
     * knew about their own project, so it gets the project's
     * directory put on the front.  An absolute one already means the
     * same thing from everywhere. */
    auto reroot = [&](const std::string& dir) {
        return file_utils::reroot(from(child->src_path), dir);
    };

    /* A forced include is a file rather than a directory, and the
     * compiler has two places to look for it: the directory it was run
     * from, and then along the include path.  The first of those is
     * the subproject's own directory to whoever wrote its Configfile,
     * so a file there gets the directory put on the front just as
     * "-I" does.  Anything else was found down the include path, and
     * has to go on being looked for by the name it was written with:
     * with the subproject's directory on the front it would be looked
     * for under that name in every include directory, which is
     * nowhere.  That makes the answer depend on what is there when
     * pconfigure runs, which is also when it reads the "#include"s. */
    auto reroot_file = [&](const std::string& file) {
        auto rerooted = file_utils::reroot(child->src_path, file);
        if (rerooted != file && access(rerooted.c_str(), F_OK) != 0)
            return file;
        return reroot(file);
    };

    auto filter_compile_opts = [&](const std::vector<std::string> compile_opts)
        {
            /* A line of COMPILEOPTS is a piece of a command line, and
             * it is the shell that splits it into the words the
             * compiler sees.  Reading it any other way -- the line as
             * one flag -- misses "-Iinc" in "-Wall -Iinc" and takes
             * the "-I" of "-I inc" for a flag with no directory on
             * it.  Splitting it here is not a change to what the
             * compiler is handed, since these are joined back up with
             * spaces on the way into the Makefile -- which is also why
             * a space with a backslash in front of it, the way
             * pkg-config spells a path with a space in it, has to stay
             * inside its word rather than being taken for the gap
             * between two. */
            auto words = std::vector<std::string>();
            for (const auto& opt: compile_opts)
                for (const auto& word: string_utils::shell_words(opt))
                    words.push_back(word);

            /* A word is matched and rerooted as the text it stands
             * for, the way the header scan reads it, and not as it was
             * written.  Written '-Iinc' or -I"/opt/inc", the word
             * starts with a quote where the flag or the directory
             * does, and taken as written the first was never seen as
             * an include directory at all -- the compiler looked for
             * inc/ at the top of the tree while the scan looked in the
             * subproject -- and the second got the subproject's
             * directory put on the front of an absolute path.
             *
             * What goes back to the shell, though, is the argument the
             * way it was written, with only the flag taken out of it
             * and the subproject's directory put on its front.  Both
             * kinds of rerooting do nothing more than that, so the
             * text it stands for comes out as the rerooted text.  The
             * quoting stays the writer's: -I"$$INC" has to go on
             * leaving $INC for the shell to expand, which spelling the
             * argument again in quotes of pconfigure's own would stop.
             * The flag goes back bare, and a quote that opened before
             * it opens again after it, because the rewriting that
             * respells the subproject's directory for a build run from
             * inside it only finds that directory at the start of a
             * word or right after "-I".
             *
             * "stuck" is whether the argument goes back on the end of
             * the flag rather than as a word of its own, and the flag
             * is empty for the word after a flag that stands alone. */
            using reroot_fn = std::function<std::string(const std::string&)>;
            auto respelled = [&](const std::string& opt,
                                 const std::string& flag,
                                 const std::string& text,
                                 const reroot_fn& with,
                                 bool stuck) {
                auto rerooted = with(text);
                if (rerooted.size() < text.size()
                    || rerooted.compare(rerooted.size() - text.size(),
                                        text.size(), text) != 0) {
                    std::cerr << "INTERNAL ERROR: rerooting \"" << text
                              << "\" gave \"" << rerooted
                              << "\", which doesn't end in it\n";
                    abort();
                }

                auto prefix = rerooted.substr(0, rerooted.size() - text.size());
                auto argument = prefix + (flag.size() == 0
                                          ? opt
                                          : written_argument(opt, flag));

                auto words = std::vector<std::string>();
                if (stuck == true)
                    words.push_back(flag + argument);
                else {
                    if (flag.size() > 0)
                        words.push_back(flag);
                    words.push_back(argument);
                }
                return words;
            };

            /* What the word after a flag that stands alone is
             * rerooted with, or nothing when the last word was no
             * such flag. */
            auto out = std::vector<std::string>();
            auto pending = reroot_fn();
            for (const auto& opt: words) {
                auto word = string_utils::shell_unescape(opt);
                auto split = split_flag(word, include_flags());
                auto forced = split_forced_include(word);

                if (pending != nullptr) {
                    out = out + respelled(opt, "", word, pending, false);
                    pending = nullptr;
                } else if (forced.first.size() > 0 && forced.second.size() == 0) {
                    out.push_back(opt);
                    pending = reroot_file;
                } else if (forced.first.size() > 0) {
                    /* Two words for the reason given for "-isystem"
                     * below. */
                    out = out + respelled(opt, forced.first, forced.second,
                                          reroot_file, false);
                } else if (split.first.size() > 0 && split.second.size() == 0) {
                    out.push_back(opt);
                    pending = reroot;
                } else if (split.first == "-I") {
                    out = out + respelled(opt, "-I", split.second, reroot, true);
                } else if (split.first.size() > 0) {
                    /* Given back as two words rather than as the one
                     * it came in.  Both mean the same to the compiler,
                     * but this line is also rewritten so that a build
                     * run from inside the subproject spells the
                     * subproject's directory with nothing on the front,
                     * and that rewriting only finds a path where a word
                     * starts or right after a two-character flag like
                     * "-I".  Stuck on to "-isystem" it would go on
                     * naming the subproject from the top of the tree,
                     * which from inside it is a directory that isn't
                     * there. */
                    out = out + respelled(opt, split.first, split.second,
                                          reroot, false);
                } else if (opt == "-std=c++11") {
#if (defined(__GNUC__) && !defined(__clang__) && (__GNUC__ == 4) && (__GNUC_MINOR__ <= 6))
                    std::cerr << "INFO: gcc-4.6 and older don't support c++11, falling back to c++0x\n";
                    out.push_back("-std=c++0x");
#else
                    out.push_back(opt);
#endif
                } else if (opt == "-std=c++14") {
#if (defined(__GNUC__) && !defined(__clang__) && (__GNUC__ == 4) && (__GNUC_MINOR__ <= 6))
                    std::cerr << "WARNING: gcc-4.6 and older don't support c++14, falling back to c++0x\n";
                    out.push_back("-std=c++0x");
#elif (defined(__GNUC__) && !defined(__clang__) && (__GNUC__ == 4) && (__GNUC_MINOR__ <= 8))
                    std::cerr << "INFO: gcc-4.8 and older don't support c++14, falling back to c++1y\n";
                    out.push_back("-std=c++1y");
#elif (defined(__clang__) && (__clang_major__ == 3) && (__clang_minor__ <= 4))
                    std::cerr << "INFO: clang-3.4 and older don't support c++14, falling back to c++1y\n";
                    out.push_back("-std=c++1y");
#else
                    out.push_back(opt);
#endif
                } else {
                    out.push_back(opt);
                }
            }
            return out;
        };

    auto full_libexec_path = child->installed(child->libexec_dir);

    return
        filter_compile_opts(this->compile_opts()) +
        filter_compile_opts(child->compile_opts) +
        std::vector<std::string>{
            "-I" + from(child->src_path) + child->unbased(child->hdr_dir),
            "-I" + from(child->hdr_dir),
            "-I" + from(child->obj_dir) + "/proc",
            "-D__PCONFIGURE__LIBEXEC=\\\"" + full_libexec_path + "\\\"",
            "-D__PCONFIGURE__PREFIX=\\\"" + ctx->prefix + "\\\""
        };

}

std::string
language_cxx::deps_suffix(const context::ptr& ctx,
                          const context::ptr& child,
                          const std::string& link,
                          const shared_target& is_shared)
                          const
{
    auto hash = hash_compile_options(ctx, child);

    /* A fragment sits beside the object it describes, because that is
     * where somebody looking for it will look.  What it cannot share
     * with the object is its name: an object belongs to whoever
     * compiled it and is used by every link whose options matched,
     * while a fragment names the links its object goes on -- so two
     * targets that compile a source the same way share one object and
     * need two fragments.
     *
     * The link directory is what tells them apart, hashed because it
     * has directories in it and this is one path component.  It was
     * doing that job before by being the directory the fragments sat
     * under; the file has moved and the job hasn't gone away. */
    return "/" + hash + "-" + hash_options({link})
        + (is_shared == shared_target::TRUE ? "-shared.d" : "-static.d");
}

std::string
language_cxx::deps_path(const context::ptr& ctx,
                        const context::ptr& child,
                        const std::string& link,
                        const shared_target& is_shared)
                        const
{
    return child->obj_dir + "/" + child->in_source_tree(child->src_dir) + "/"
        + child->cmd->data() + deps_suffix(ctx, child, link, is_shared);
}

/* One of these per set of compile options rather than per source,
 * because that is the granularity everything else here has: the
 * options are hashed into the object's name, so two sources compiled
 * the same way are two sources with one answer to every question pdeps
 * asks -- in each language, since the language's own compiler and
 * options are among those hashed. */
std::string
language_cxx::deps_context_path(const context::ptr& ctx,
                                const context::ptr& child,
                                const std::string& link)
                                const
{
    return link + "deps-context-"
        + hash_compile_options(ctx, child)
        + project::base_suffix(child->base);
}

std::string
language_cxx::write_deps_context(const context::ptr& ctx,
                                 const context::ptr& child,
                                 const std::string& link,
                                 const shared_target& is_shared,
                                 const behind_languages& behind,
                                 const std::string& named)
                                 const
{
    auto hash = hash_compile_options(ctx, child);
    auto obj_prefix =
        child->obj_dir + "/" + child->in_source_tree(child->src_dir) + "/";
    auto deps_suffix = this->deps_suffix(ctx, child, link, is_shared);
    auto context_path = deps_context_path(ctx, child, link);

    auto say = [](const std::string& key, const std::string& value)
        { return key + " " + value + "\n"; };

    auto out = std::string();

    /* Halves rather than whole paths, because pdeps has to be able to
     * name a source this never mentioned.  Sticking a name in the
     * middle of these is the same arithmetic compile_source() does,
     * and it is the only arithmetic pdeps is trusted with. */
    out += say("src-prefix", child->src_dir + "/");
    out += say("obj-prefix", obj_prefix);
    out += say("obj-suffix",
               "/" + hash
               + (is_shared == shared_target::TRUE ? "-shared.o"
                                                   : "-static.o"));
    out += say("dep-prefix", obj_prefix);
    out += say("dep-suffix", deps_suffix);

    out += say("compiler", this->compiler_command(child));
    out += say("pretty", this->compiler_pretty());
    if (is_shared == shared_target::TRUE)
        out += say("pic", "-fPIC");

    out += say("pdeps", makefile::tool_path("pdeps"));
    out += say("quiet", child->verbose ? "false" : "true");
    out += say("autodeps", ctx->autodeps ? "true" : "false");

    /* The headers the build makes, which pdeps has to count as found
     * when it scans while one of them is missing -- see build_made on
     * the context for when that is, and what it costs not to. */
    for (const auto& made: ctx->build_made)
        out += say("made", made);

    /* Only a project a parent can include has anything to say here.
     * The peers are deliberately not passed along: a path into a
     * sibling project is one that only means anything from the top of
     * the tree, and leaving it alone is the only spelling that is
     * right there. */
    if (child->base.size() > 0) {
        out += say("base", child->base);
        out += say("variable", project::prefix_variable(child->base));

        /* Where this file is, said from the same place every other
         * path here is said from -- which is what lets pdeps work
         * out where it is standing.  The prefixes above are spelled
         * from the top of the tree because that is where pconfigure
         * ran, and they are the only spelling that is right there;
         * but make hands pdeps a --context through the variable, so
         * a build run from inside the subproject spells the same
         * file with nothing on the front.  Lining that up against
         * this is the whole of the arithmetic.  Without it pdeps
         * has no way to tell the two apart, and it guesses that it
         * is at the top -- which puts its answer in a directory
         * named after the project inside the project, and makes
         * that answer say every source has been deleted. */
        out += say("self", context_path);
    }

    /* The link steps this source's object belongs to.  Which of them
     * exist is link_objects()' answer, and this has to give the same
     * one: an object that never reached the installed link is a
     * "make install" that installs a program built out of whatever
     * was lying around.
     *
     * A static archive has the one step both of its copies come from,
     * and an object that is a prerequisite of a link step that doesn't
     * exist is an object that's built and then archived nowhere. */
    if (ctx->is_static_archive()) {
        out += say("link", link + "archive");
    } else {
        if (ctx->install == true)
            out += say("link", link + "install");
        out += say("link", link + "local");
    }

    /* The sources this target's Configfile named outright, which are
     * the ones whose fragments have a rule in the Makefile already.
     * A named source can also turn up behind another source's header,
     * and then both this and pdeps would write a rule for the same
     * fragment -- which make resolves by picking one and saying so in
     * a warning nobody reads.
     *
     * pdeps still has to be the one that pulls such a fragment in,
     * even though it is not the one that builds it: where the include
     * sits is what decides where the objects land on the link line,
     * and that has to be where the walk reached them.
     *
     * Each is said with the fragment its rule writes, because a named
     * source is built the way its own SOURCES line says even when the
     * walk reaches it through somebody else's header -- and that line
     * can carry options of its own, which puts its fragment somewhere
     * pdeps cannot work out from the halves above.
     *
     * Worked out by deps_source() rather than here, because this is
     * also how another language writes its own one of these, and a
     * named source is in the target's language whoever is asking:
     * its fragment is spelled with the target's compiler. */
    out += named;

    /* And where the rest of what the walk finds is described: the
     * sources behind this one's headers that nobody named are built
     * with the target's options rather than with this source's (see
     * behind_header_context()), so their fragments come from the
     * context for those options.  That is this file whenever this
     * source has no options of its own, and another file, written
     * here too, when it does -- nothing else need ever have asked
     * for one.
     *
     * When this isn't the target's language, those options are the
     * target's less its COMPILER, the same as compile_source() builds
     * them with (see foreign_context()).  Its own COMPILER left in,
     * the file is named the way the target language's own one is, and
     * one of them overwrites the other. */
    {
        auto plain = foreign_context(
            ctx->dup(context_type::SOURCE, child->cmd, {}), this, behind);
        auto plain_path = deps_context_path(ctx, plain, link);
        if (plain_path != context_path)
            write_deps_context(ctx, plain, link, is_shared, behind, named);
        out += say("behind", plain_path);
    }

    for (const auto& opt: compile_options(ctx, child))
        out += say("opt", opt);

    /* Which of those is compiled by some other language, and where
     * that language's own one of these is: it has the compiler, the
     * options and the object names they hash to.  Only the endings
     * that leave this language are listed, so a walk that never
     * crosses into another one reads nothing it didn't read before.
     * The file named is the one for the target's options, because
     * those are the only ones a source nobody named is built with. */
    {
        auto plain = ctx->dup(context_type::SOURCE, child->cmd, {});
        for (const auto& entry: behind)
            if (entry.second != this)
                out += say("behind-language",
                           entry.first + " "
                           + entry.second->deps_context_path(
                                 ctx,
                                 foreign_context(plain, entry.second,
                                                 behind),
                                 link));
    }

    /* Written only when it would say something new, because it is a
     * prerequisite of every fragment below it: a file rewritten by
     * each configure is every dependency in the project worked out
     * again, whether or not anything changed. */
    file_utils::mkdir_p(link);
    file_utils::write_configure_output(context_path, out);
    return context_path;
}

makefile::target::ptr
language_cxx::deps_source(const context::ptr& ctx,
                          const context::ptr& child,
                          const shared_target& is_shared,
                          const behind_languages& behind)
                          const
{
    /* The link this target's objects go on, which is the target's
     * own whichever language compiled them.  Every other language's
     * context below is handed it rather than working one out: its
     * linker is in the hash that names a link directory, and a link
     * directory named after a linker this target doesn't use is a
     * link nothing ever runs. */
    auto link = link_dir(ctx);

    auto named = std::string();
    for (const auto& sibling: ctx->children)
        if (sibling->type == context_type::SOURCE)
            named += "named " + sibling->cmd->data() + " "
                   + deps_path(ctx, sibling, link, is_shared) + "\n";

    auto source_path = child->src_dir + "/" + child->cmd->data();
    auto deps_path = this->deps_path(ctx, child, link, is_shared);
    auto context_path =
        write_deps_context(ctx, child, link, is_shared, behind, named);

    /* And one for every other language a source found behind a header
     * might be compiled by, which pdeps reads only when the walk gets
     * there.  It can't be written by pdeps when it does: everything
     * in it is pconfigure's to know, from what that language was told
     * in the Configfile to which compiler it runs.  Only the one for
     * the target's options, which is the only one the walk asks
     * for. */
    auto plain = ctx->dup(context_type::SOURCE, child->cmd, {});
    auto written = std::set<const language_cxx*>{this};
    for (const auto& entry: behind)
        if (written.insert(entry.second).second == true)
            entry.second->write_deps_context(ctx,
                                             foreign_context(plain,
                                                             entry.second,
                                                             behind),
                                             link, is_shared, behind, named);

    /* Through "$(wildcard)", which is how pdeps names the sources it
     * finds behind a header, and for the same reason: a source that
     * has been deleted since is a prerequisite make has no rule for,
     * and naming it outright stops the build rather than asking the
     * question again.  A Configfile naming a source is no guarantee
     * the source is still there. */

    /* And pdeps itself, because a fragment is not the source it
     * describes: it is what one version of pdeps made of that source,
     * and a pdeps that has learned to see something new has to be
     * allowed to say so.  Nothing noticed before.  The path pdeps was
     * found at goes into the context file above, which is a
     * prerequisite -- so a pconfigure that moved, or was reinstalled
     * somewhere else, already invalidated every fragment in the tree.
     * A pconfigure rebuilt where it stood did not, and a vendored
     * pconfigure is rebuilt where it stood every time somebody edits
     * it, which is the one case this project is.
     *
     * Named the way tool_path() says it, which is an absolute path
     * -- deliberately, and not to be helpfully shortened later.  A
     * tree that vendors pconfigure has a rule for that binary under
     * the relative spelling, and make does not treat the two
     * spellings as the same file: as an absolute path this is a
     * prerequisite with no rule, which is to say a timestamp and
     * nothing more, and that is the whole of what is wanted here.
     * Spell it relatively instead and make finds the rule -- during
     * the phase where it is remaking the included fragments, which is
     * before it has read the fragments that say which objects the
     * binary is built out of, so it links it out of none of them.
     *
     * Through "$(wildcard)" for the same reason as the source above,
     * and one more: "make clean" deletes the vendored pconfigure
     * along with everything else the build produced.  A bare path
     * would turn every build after a clean into "No rule to make
     * target", with every fragment in the tree perfectly current.
     * Asking whether the file is there gets today's behaviour back
     * when it is not, and it covers the case where the tool is a bare
     * command name off the PATH rather than a path at all.
     *
     * pdeps gets this, and psubdeps gets the same treatment over in
     * the kconfig build system.  pbashc, ptest, phc, pperlc and
     * pswigcc do not, and that is a decision rather than a list
     * somebody stopped writing halfway down.  Those tools produce
     * build outputs, where a stale answer is one file that is out of
     * date and a rebuild of it puts things right.  These two produce
     * the dependency graph itself, where a stale answer is a whole
     * tree quietly believing the wrong thing about what it depends on
     * -- which is not something a later build notices, because
     * noticing is exactly what it has lost.  Closing the hole for the
     * rest would rebuild everything every time any of them is
     * touched, and in a tree that vendors pconfigure that is every
     * time pconfigure is touched.  Worth revisiting one day; not
     * worth doing by accident, in either direction. */
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
            + " --source " + child->cmd->data()
    };

    return std::make_shared<makefile::target>(
        deps_path,
        "DEPS\t" + child->cmd->data(),
        deps,
        std::vector<makefile::global_targets>{
            makefile::global_targets::CLEAN
        },
        commands,
        std::vector<std::string>{
            std::to_string(child->cmd->debug()),
            "language_cxx::deps_source()"
        }
    )->as_included();
}

/* Every path this writes into a recipe is a bare word, and that is
 * deliberate rather than an oversight waiting to be tidied up: a file
 * or directory whose name holds a quote, a space or a shell
 * metacharacter does not build, here or anywhere else in pconfigure.
 * Quoting these recipes does not fix it and is not wanted -- a
 * subproject's paths arrive as an expansion of the make variable that
 * stands for its directory, so quotes round the reference quote
 * nothing that is inside it, and that variable cannot hold an escaped
 * path because it also names make prerequisites.  The reasoning, and
 * what a real fix would cost, is on makefile::path_prefix and under
 * "Odd Behavior" in doc/pconfigure.tex. */
std::vector<language_cxx::target::ptr>
language_cxx::compile_source(const context::ptr& ctx,
                             const context::ptr& child,
                             std::vector<std::string>& processed,
                             const shared_target& is_shared,
                             const behind_languages& behind)
                             const
{
    auto source_path = child->src_dir + "/" + child->cmd->data();

    auto compile_opts = compile_options(ctx, child);
    auto shared_comments = std::vector<std::string>{
        std::to_string(child->cmd->debug()),
        "language_cxx::compile_source()",
        "compile_opts: " + vector_util::join(compile_opts, " ")
    };

    auto base_out_name =
        child->obj_dir
        + "/" + child->in_source_tree(child->src_dir)
        + "/" + child->cmd->data()
        + "/" + hash_compile_options(ctx, child);

    /* Recursively walks the list of targets. */
    std::vector<target::ptr> deps;
    std::vector<target::ptr> header_deps;
    for (const auto& header_dep: dependencies(source_path,
                                              is_shared,
                                              compile_opts)) {
        /* A header this source reads is a prerequisite of the object
         * built from it whatever else is going on, and AUTODEPS has
         * nothing to say about that.  What AUTODEPS turns off is the
         * loop below -- the sources behind those headers getting
         * built and linked in alongside this one -- and a target that
         * doesn't want that still wants to be rebuilt when a
         * declaration it was compiled against moves.  Without this
         * the object stays as it was, and what comes out is a program
         * built half against the old header and half against the
         * new. */
        {
            /* The header is a prerequisite, so it is spelled as one
             * when it is written out; but a few characters have no
             * spelling, and a rule that named some other file than
             * the header would be wrong in a way nobody would look
             * for.  Nothing in the Configfile named it, so what is
             * pointed at is the line naming the source that reads
             * it. */
            auto why = makefile::unspellable(header_dep);
            if (why.size() > 0) {
                std::cerr << std::to_string(child->cmd->debug()) << "\n"
                          << "  error: '" << source_path
                          << "' reads the header '" << header_dep
                          << "', which the Makefile cannot name\n"
                          << "  the header is a prerequisite of the"
                          << " object built from that source, and "
                          << why << "\n"
                          << "  rename the header -- letters, digits,"
                          << " '-', '_', '.' and spaces are all safe --"
                          << " and include it by that name\n";
                abort();
            }

            auto t = std::make_shared<header_target>(header_dep);
            header_deps = header_deps + std::vector<header_target::ptr>{t};
        }

        if (ctx->autodeps == true) {
            for (const auto& dep: find_files_for_header(header_dep)) {
                auto src_prefix = child->src_dir + "/";
                if (dep.compare(0, src_prefix.size(), src_prefix) != 0)
                    continue;
                std::string stripped_dep = dep.substr(src_prefix.size());

                /* A source found here is built, which a header is
                 * not: its name goes on the left of the rule for its
                 * object, into the object's own name, and bare into
                 * the compile recipe -- every place a SOURCES line's
                 * name goes, so it is held to what one of those is
                 * held to.  A header with a space or a '#' in its name
                 * is spelled for make and builds; the source beside it
                 * cannot be, since the shell half of that is a rewrite
                 * of every recipe, which make_special_character()
                 * explains turning down.  Said here rather than left to
                 * make, which would otherwise stop on a rule line
                 * nobody wrote, or hang restarting under
                 * AUTORECONFIGURE. */
                for (const auto& c: stripped_dep) {
                    auto why = make_special_character(c);
                    if (why.size() == 0)
                        continue;

                    std::cerr << std::to_string(child->cmd->debug())
                              << "\n"
                              << "  error: '" << source_path
                              << "' reads '" << header_dep
                              << "', and the source behind it, '" << dep
                              << "', has a '"
                              << (c == '\n' ? std::string("\\n")
                                  : c == '\t' ? std::string("\\t")
                                  : std::string(1, c))
                              << "' in its name\n"
                              << "  a source found behind a header is"
                              << " built into this target, which makes it"
                              << " the name of something the Makefile"
                              << " builds, and " << why << "\n"
                              << "  rename the source without it --"
                              << " letters, digits, '-', '_' and '.' are"
                              << " all safe -- and the header beside it to"
                              << " match, or, if it was never meant to be"
                              << " built into this target, set AUTODEPS ="
                              << " false on the target\n";
                    abort();
                }

                /* Compiled by the language whose file it is, which
                 * isn't necessarily this one.  That language's
                 * compiler is in the object's name, so asking it here
                 * is also what keeps the C and the C++ object of one
                 * source from being taken for each other below. */
                auto owner = static_cast<const language_cxx*>(this);
                for (const auto& entry: behind)
                    if (string_utils::has_extension(dep, entry.first))
                        owner = entry.second;

                auto dep_ctx = foreign_context(
                    behind_header_context(ctx,
                                          stripped_dep,
                                          child->cmd->debug()),
                    owner,
                    behind);

                auto dep_out_name =
                    dep_ctx->obj_dir
                    + "/" + dep_ctx->in_source_tree(dep)
                    + "/" + owner->hash_compile_options(ctx, dep_ctx);

                bool should_process = true;
                for (const auto& p: processed)
                    if (strcmp(p.c_str(), dep_out_name.c_str()) == 0)
                        should_process = false;
                if (should_process == false)
                    continue;
                processed.push_back(dep_out_name);

                deps = deps + owner->compile_source(ctx, dep_ctx, processed,
                                                    is_shared, behind);
            }
        }
    }

    /* There's two targets here: one for staticly linked programs, and ony for
     * dynamically linked ones. */
    auto static_ctarget = std::make_shared<compile_target>(
        base_out_name + "-static.o",
        source_path,
        language_cxx::shared_target::FALSE,
        shared_comments + std::vector<std::string>{"static_target"},
        compile_opts,
        child,
        header_deps,
        this->compiler_command(child),
        this->compiler_pretty()
    );

    auto shared_ctarget = std::make_shared<compile_target>(
        base_out_name + "-shared.o",
        source_path,
        language_cxx::shared_target::TRUE,
        shared_comments + std::vector<std::string>{"shared_target"},
        compile_opts,
        child,
        header_deps,
        this->compiler_command(child),
        this->compiler_pretty()
    );

    switch (is_shared) {
    case shared_target::TRUE:
        deps = deps + std::vector<compile_target::ptr>{shared_ctarget};
        break;
    case shared_target::FALSE:
        deps = deps + std::vector<compile_target::ptr>{static_ctarget};
        break;
    };

    return deps;
}

/* A COMPILEOPTS written under a SOURCES is for that one source, and a
 * source found behind its header is not that source: it is one the
 * target needs because of what the header promised, and it is the same
 * source whichever of the target's files happened to read the header
 * first.  So it is built the way the target builds everything it was
 * not told anything particular about, which is the target's own
 * options.
 *
 * Inheriting the options of whatever led to it was how this used to
 * work, and it is wrong in a way that does not stay quiet: two sources
 * that read one header with different options of their own each want
 * the source behind it built their way, which is two objects defining
 * the same symbols on one link line.  Under AUTORECONFIGURE it is
 * worse, if anything -- a source the Configfile also named has a
 * fragment rule for one set of options, and the walk asks for the
 * other.
 *
 * The exception is a source the Configfile named outright.  That
 * already has a SOURCES line saying how it is built, options and all,
 * and reaching it through a header does not make it a different
 * source: it is built the way that line says, which is also what lets
 * the two routes to it come out as one object. */
context::ptr
language_cxx::behind_header_context(const context::ptr& ctx,
                                    const std::string& name,
                                    const debug_info::ptr& debug)
                                    const
{
    for (const auto& sibling: ctx->children)
        if (sibling->type == context_type::SOURCE
            && sibling->cmd->data() == name)
            return sibling;

    auto cmd = std::make_shared<command>(command_type::SOURCES,
                                         "+=",
                                         name,
                                         debug);
    return ctx->dup(context_type::SOURCE, cmd, {});
}

/* The context a source found behind a header is compiled in by the
 * language that owns it.  A COMPILER written on the target was said to
 * the target's language, so a source some other language compiles goes
 * back to that language's own compiler -- whatever it was told under
 * its LANGUAGES line, or its default -- which is what the manual
 * promises for a C++ file behind a C program's header.  Leaving the
 * target's in place compiles that file with a C compiler, which fails
 * on the first line that is C++ and reads like a mistake in the source
 * rather than in the Configfile.
 *
 * It is the target's language that is compared against rather than
 * whichever one is doing the walking, because the walk crosses
 * languages: from a C++ source behind the header, a C source behind
 * the next one is back in the target's language, and the target's
 * COMPILER is the one for it.
 *
 * Every route to such a source has to come through here, because the
 * compiler is also in the hash that names the object: the walk this
 * pconfigure does and the one pdeps does under AUTORECONFIGURE have to
 * agree on the name, or the target links an object nothing builds. */
context::ptr
language_cxx::foreign_context(const context::ptr& plain,
                              const language_cxx* owner,
                              const behind_languages& behind)
{
    if (owner == behind.target)
        return plain;
    return plain->without_compiler();
}

std::vector<std::string> language_cxx::dependencies(
    const std::string& filename,
    const shared_target& is_shared __attribute__((unused)),
    const std::vector<std::string>& compile_opts) const
{
    return cxx_headers_read_by(filename, compile_opts);
}

std::vector<std::string>
cxx_headers_read_by(const std::string& source,
                    const std::vector<std::string>& compile_opts,
                    const std::vector<std::string>& promised,
                    const pinclude::missed_callback& on_missed)
{
    auto defined = std::unordered_set<std::string>();
    for (const auto& define: cxx_defines(compile_opts))
        defined.insert(define);
    auto include_dirs = cxx_include_search(compile_opts);

    auto promised_set = std::unordered_set<std::string>(promised.begin(),
                                                        promised.end());

    /* A header found through an absolute directory comes back
     * absolute, and that is how pkg-config names a subproject's
     * include directory.  Spelled from here instead, it's the same
     * name the subproject's Makefile gives the header it installs
     * there, and it doesn't carry the path of the checkout into the
     * Makefile as a prerequisite -- which make, having no quoting for
     * a prerequisite, splits at the first space in "my checkout". */
    auto out = std::vector<std::string>();
    auto callback = [&](std::string s) {
        out.push_back(relative_to_here(s));
        return 0;
    };

    /* Spelled the way the headers are, for the same reason: they are
     * written into the same fragment. */
    auto missed = pinclude::missed_callback();
    if (on_missed != nullptr)
        missed = [&](const std::string& s) {
            on_missed(relative_to_here(s));
        };

    /* A forced include is looked for where the compiler looks for it:
     * in the directory the compiler runs from first, rather than the
     * one the source is in, and then along the include path the way a
     * '#include "..."' is.  One that isn't anywhere is skipped, the
     * same as an "#include" of a file that isn't there: the compiler
     * has the better sentence to say about that. */
    auto includable = [](const std::string& path) {
        struct stat st;
        if (stat(path.c_str(), &st) != 0)
            return false;
        return !S_ISDIR(st.st_mode) && access(path.c_str(), R_OK) == 0;
    };

    /* What the search passes over on the way is reported the way
     * pinclude reports it for an "#include", since a forced include
     * can be shadowed in all the same ways: only where nothing at all
     * is there now. */
    auto miss = [&](const std::string& path) {
        struct stat st;
        if (missed != nullptr && lstat(path.c_str(), &st) != 0)
            missed(file_utils::normalize_path(path));
    };

    for (const auto& name: cxx_forced_includes(compile_opts)) {
        auto found = std::string();
        if (includable(name))
            found = name;
        else {
            miss(name);
            if (name[0] != '/')
                for (const auto& dir: include_dirs.quoted()) {
                    if (found.size() > 0)
                        break;
                    if (includable(dir + "/" + name))
                        found = dir + "/" + name;
                    else
                        miss(dir + "/" + name);
                }
        }

        if (found.size() == 0)
            continue;

        /* What it defines is defined before the source's first line,
         * so it is read with the same set of defines the source is
         * read with afterwards, and leaves its own in there. */
        found = file_utils::normalize_path(found);
        out.push_back(relative_to_here(found));
        pinclude::list_defining(found,
                                include_dirs,
                                defined,
                                callback,
                                true,
                                promised_set,
                                missed);
    }

    pinclude::list(source,
                   include_dirs,
                   defined,
                   callback,
                   true,
                   pinclude::syntax::C,
                   {},
                   false,
                   false,
                   promised_set,
                   missed);
    return out;
}

static std::vector<std::string> link_dirs(const std::vector<std::string>& args)
{
    auto out = std::vector<std::string>();
    auto pending = false;

    /* These are compared with the directories this build puts its
     * libraries in, so it's the path that's wanted rather than the
     * shell's spelling of it: pkg-config hands back the "-L" for a
     * subproject checked out under "R&D" as ".../R\&D/sub/lib", and
     * with the backslash left in that's nowhere in this build, so the
     * binary got no rpath to find the library at. */
    for (const auto& arg: args) {
        if (pending == true) {
            out.push_back(string_utils::shell_unescape(arg));
            pending = false;
        } else if (arg == "-L") {
            pending = true;
        } else if (arg.compare(0, 2, "-L") == 0) {
            out.push_back(string_utils::shell_unescape(arg.substr(2)));
        }
    }

    return out;
}

/* Whether a path is a file the linker could read, as opposed to a
 * directory or nothing at all. */
static bool is_regular_file(const std::string& path)
{
    struct stat st;
    if (stat(path.c_str(), &st) != 0)
        return false;
    return S_ISREG(st.st_mode);
}

/* The flags a linker reads a file for, which are all of them that
 * name an input rather than an output.  "-Map" and "--out-implib"
 * name a file too, but the link writes those, and an output taken for
 * an input is a link that is never up to date: the map is written a
 * moment after the program is.  So this is a list of the ones known
 * to be read rather than a guess from the shape of the argument, and
 * something missing from it is a file that changes without a relink,
 * which is what everything was before. */
static const std::vector<std::string>& linker_file_flags(void)
{
    static const auto out = std::vector<std::string>{
        "version-script",
        "script",
        "dynamic-list",
        "retain-symbols-file",
        "just-symbols",
        "export-dynamic-symbol-list",
    };
    return out;
}

static std::vector<std::string>
link_input_files(const std::vector<std::string>& args)
{
    auto candidates = std::vector<std::string>();

    /* What the linker itself is handed, a word at a time, whichever
     * way the compiler driver was asked to pass it along.  A file can
     * be the word after its flag, and that word can come in through a
     * different "-Wl," or "-Xlinker" than the flag did -- "-Xlinker
     * --version-script -Xlinker x.map" is the only way that spelling
     * has of saying it -- so whether a file is due carries over from
     * one to the next. */
    auto linker_pending = false;
    auto linker_word = [&](const std::string& word) {
        if (linker_pending == true) {
            candidates.push_back(word);
            linker_pending = false;
            return;
        }

        /* "-T" is the one short flag, and the only one that takes its
         * file stuck straight on. */
        if (word == "-T") {
            linker_pending = true;
            return;
        }
        if (word.compare(0, 2, "-T") == 0) {
            candidates.push_back(word.substr(2));
            return;
        }

        /* GNU ld takes a long option with either one dash or two, and
         * its argument either after an '=' or as the next word. */
        if (word.size() < 2 || word[0] != '-')
            return;
        auto name = word.substr(word[1] == '-' ? 2 : 1);
        auto equals = name.find('=');
        auto flag = name.substr(0, equals);
        if (std::find(linker_file_flags().begin(),
                      linker_file_flags().end(),
                      flag) == linker_file_flags().end())
            return;
        if (equals == std::string::npos)
            linker_pending = true;
        else
            candidates.push_back(name.substr(equals + 1));
    };

    auto pending = std::string();
    for (const auto& arg: args) {
        if (pending == "-Xlinker") {
            linker_word(arg);
            pending = "";
            continue;
        }
        if (pending == "-T") {
            candidates.push_back(arg);
            pending = "";
            continue;
        }

        if (arg == "-Xlinker" || arg == "-T") {
            pending = arg;
            continue;
        }

        if (arg.compare(0, 4, "-Wl,") == 0) {
            auto pieces = std::stringstream(arg.substr(4));
            auto piece = std::string();
            while (std::getline(pieces, piece, ','))
                linker_word(piece);
            continue;
        }

        if (arg.compare(0, 2, "-T") == 0) {
            candidates.push_back(arg.substr(2));
            continue;
        }

        /* A file named outright, which is how a prebuilt archive or
         * object gets linked in.  Requiring a '/' is what needs() does
         * for the same words, and keeps a flag's argument -- the
         * "Foo" of "-framework Foo", the symbol of "-u sym" -- from
         * being taken for a file that happens to share its name. */
        if (arg.size() > 0
            && arg[0] != '-'
            && arg.find('/') != std::string::npos)
            candidates.push_back(arg);
    }

    /* Only what is there now.  A file this build makes and hasn't
     * yet is found through needs() instead, and one that is nowhere
     * is a link that fails and says so.  A name make would split in
     * two can't be a prerequisite at all, so it is left as it was:
     * unwatched, but linked. */
    auto out = std::vector<std::string>();
    for (const auto& raw: candidates) {
        auto path = string_utils::shell_unescape(raw);
        if (path.find_first_of(" \t\n") != std::string::npos)
            continue;
        if (is_regular_file(path) == false)
            continue;

        /* Spelled the way a rule that makes it would spell it, so
         * that the two are one file to make. */
        auto name = file_utils::normalize_path(relative_to_here(path));
        if (std::find(out.begin(), out.end(), name) == out.end())
            out.push_back(name);
    }

    return out;
}

/* Most paths on a command line got there relative to where pconfigure
 * is running, but not all: what pkg-config says about a package is
 * absolute, because a .pc file has to mean the same thing to whoever
 * reads it, and so is a header an "#include" names by its full path.
 * Both have to be spelled the same way to be recognized as the same
 * file.
 *
 * Which leading part of an absolute path is this directory is asked
 * of the filesystem rather than of getcwd()'s string.  getcwd() gives
 * the path with every symlink resolved, while whoever wrote the
 * absolute path most likely took it from $PWD, which keeps them: a
 * checkout reached through a symlinked home directory, or on macOS
 * anything under /var or /tmp, which are links into /private.  The
 * prefix didn't match, the header stayed absolute, and as a name no
 * rule makes it was never linked to the source behind it.  The
 * longest leading directory that is this one wins, so that a
 * directory reached by way of a link to itself further down comes
 * out as the plain name and not as one spelled through the link. */
static std::string relative_to_here(const std::string& dir)
{
    if (dir.size() == 0 || dir[0] != '/')
        return dir;

    struct stat here;
    if (stat(".", &here) != 0)
        return dir;

    for (auto slash = dir.find_last_of('/');
         slash != std::string::npos && slash > 0;
         slash = dir.find_last_of('/', slash - 1)) {
        struct stat st;
        auto prefix = dir.substr(0, slash);
        if (stat(prefix.c_str(), &st) != 0)
            continue;
        if (st.st_dev != here.st_dev || st.st_ino != here.st_ino)
            continue;

        /* What follows the run of slashes after the directory, so
         * that "/here//src/x.h" is "src/x.h" and not "/src/x.h".  This
         * directory itself, written with a trailing slash, is nothing
         * at all from here, which canonical_dir() spells as ".". */
        auto rest = dir.find_first_not_of('/', slash);
        if (rest == std::string::npos)
            return "";
        return dir.substr(rest);
    }

    return dir;
}

/* The name to ask for a directory by, which has to be the same name
 * whoever built it offers it under.  That's library_capability()'s
 * spelling: no trailing '/', and "." for the directory pconfigure ran
 * in.  normalize_path() keeps a trailing slash, since that's how a
 * path says it names a directory, but here every caller already knows
 * it has a directory and sticks a "/" and a name on the end of it --
 * so "-Lsub/libs/" has to ask for "sub/libs/name" rather than
 * "sub/libs//name", which nothing offers.  The root directory comes
 * out empty, which is how library_capability() spells it too. */
static std::string canonical_dir(const std::string& dir)
{
    auto out = file_utils::normalize_path(relative_to_here(dir));

    /* Only a relative path that normalizes to nothing, like "./",
     * comes out of normalize_path() empty. */
    if (out.size() == 0)
        return ".";

    if (out[out.size() - 1] == '/')
        out.pop_back();
    return out;
}

/* The suffixes a linker will look for when it's asked for "-lfoo".
 * LIBRARIES are named explicitly in a Configfile, so a project picks
 * its own suffix and all of these are worth recognizing. */
static const std::vector<std::string> library_suffixes = {
    ".so",
    ".dylib",
    ".a",
};

/* Turns a path like "lib/libfoo.so" into the "-Llib -lfoo" that would
 * name it, spelled the way needs() below spells it.  Returns an empty
 * string for a path that no "-l" could ever refer to. */
static std::string library_capability(const std::string& raw)
{
    auto path = file_utils::normalize_path(raw);
    auto slash = path.find_last_of('/');
    auto dir = (slash == std::string::npos)
        ? std::string(".")
        : path.substr(0, slash);
    auto file = (slash == std::string::npos)
        ? path
        : path.substr(slash + 1);

    if (file.compare(0, 3, "lib") != 0)
        return "";

    for (const auto& suffix: library_suffixes) {
        if (file.size() <= 3 + suffix.size())
            continue;
        if (file.compare(file.size() - suffix.size(),
                         suffix.size(),
                         suffix) != 0)
            continue;

        auto name = file.substr(3, file.size() - 3 - suffix.size());
        return "library:" + dir + "/" + name;
    }

    return "";
}

std::vector<std::string>
language_cxx::provides(const makefile::target::ptr& target) const
{
    auto out = language::provides(target);


    /* A library offers itself under the name a link line would use to
     * ask for it, so that whether it's called "libfoo.so" or
     * "libfoo.a" is this side's problem rather than the asking
     * side's. */
    auto library = library_capability(target->name());
    if (library.size() > 0)
        out.push_back(library);

    return out;
}

std::vector<std::string>
language_cxx::needs(const makefile::target::ptr& target) const
{
    /* Read the way the shell that runs these commands will read them,
     * and then taken back to the text each word stands for, since
     * what's wanted out of them is files and directories: a "-L" for
     * a subproject checked out somewhere with a space in its name is
     * one word with a backslash in it, not two. */
    auto args = std::vector<std::string>();
    for (const auto& cmd: target->cmds())
        for (const auto& arg: string_utils::shell_words(cmd))
            args.push_back(string_utils::shell_unescape(arg));

    auto search_dirs = std::vector<std::string>();
    auto library_names = std::vector<std::string>();
    auto out = std::vector<std::string>();

    /* Both "-L dir" and "-Ldir" are legal, so a flag that's on its own
     * takes its argument from the next word. */
    auto pending = std::string();
    for (const auto& arg: args) {
        if (pending.size() > 0) {
            if (pending == "-L")
                search_dirs.push_back(arg);
            else
                library_names.push_back(arg);
            pending = "";
            continue;
        }

        if (arg == "-L" || arg == "-l") {
            pending = arg;
            continue;
        }

        if (arg.compare(0, 2, "-L") == 0) {
            search_dirs.push_back(arg.substr(2));
            continue;
        }

        if (arg.compare(0, 2, "-l") == 0) {
            library_names.push_back(arg.substr(2));
            continue;
        }

        /* Anything that isn't a flag but does look like a path might
         * name a file outright, which is how a static archive that's
         * passed positionally gets picked up.  Requiring a '/' keeps
         * this from matching bare words like "cat" or "mv". */
        if (arg.size() > 0
            && arg[0] != '-'
            && arg.find('/') != std::string::npos)
            out.push_back("file:" + canonical_dir(arg));
    }

    /* Which of the search directories a library actually turns up in
     * is the linker's business, so ask for it in all of them and let
     * the ones that nothing builds go unanswered. */
    for (const auto& dir: search_dirs) {
        for (const auto& name: library_names) {
            /* "-l:libfoo.a" is GNU ld asking for a file by its exact
             * name rather than for a library by its short one, still
             * searched for along the "-L" directories.  No "lib"
             * prefix or suffix is added, so what it wants is just
             * that file in each directory, which every target
             * already offers under its own name. */
            if (name.size() > 1 && name[0] == ':') {
                auto file = dir + "/" + name.substr(1);
                out.push_back("file:" + canonical_dir(file));
                continue;
            }

            out.push_back("library:" + canonical_dir(dir) + "/" + name);
        }
    }

    return out;
}

static void install_cxx(void) __attribute__((constructor));
void install_cxx(void)
{
    language_list::global_add(
        std::make_shared<language_cxx>(
            std::vector<std::string>{},
            std::vector<std::string>{}
        )
    );
}
