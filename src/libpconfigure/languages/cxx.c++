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
#include "../language_list.h++"
#include "../vector_util.h++"
#include "../pick_language.h++"
#include <pinclude.h++>
#include <unistd.h>
#include <fcntl.h>
#include <iostream>

language_cxx* language_cxx::clone(void) const
{
    return new language_cxx(this->list_compile_opts(),
                            this->list_link_opts());
}

bool language_cxx::can_process(const context::ptr& ctx) const
{
    if (language::all_sources_match(ctx,
                                    {std::regex(".*\\.C"),
                                     std::regex(".*\\.cxx")})) {
        return true;
    }

    /* This works around a C++11 regex bug in GCC versions prior to
     * 4.9 -- specifically, I can't match the "c++" extension because
     * the old regex implementation doesn't appear to support escaping
     * the '+' character. */
    if (language::all_sources_match(ctx, {std::regex(".*\\.c..")})) {
        for (const auto& child: ctx->children) {
            switch (child->type) {
            case context_type::DEFAULT:
            case context_type::GENERATE:
            case context_type::LIBRARY:
            case context_type::BINARY:
            case context_type::TEST:
            case context_type::HEADER:
                break;

            case context_type::SOURCE:
            {
                auto file = child->cmd->data();
                if (file.find(".c++", file.length() - 5) == std::string::npos)
                    return false;
            }
            }
        }

        return true;
    }

    return false;
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
            break;
    }

    std::cerr << "language_cxx: Internal error in is_shared_target()" << std::endl;
    abort();
}

std::string language_cxx::hash_link_options(const context::ptr& ctx) const
{
    return hash_options(
        std::vector<std::string>{this->linker_command()}
        + this->clopts()
        + ctx->clopts()
    );
}

std::string language_cxx::hash_compile_options(const context::ptr& ctx) const
{
    return hash_options(
        std::vector<std::string>{this->compiler_command()}
        + this->compile_opts()
        + ctx->list_compile_opts()
    );
}

std::string language_cxx::hash_options(const std::vector<std::string>& opts) const
{
    std::hash<std::string> hash_fn;
    uint32_t seed = 5831;
    for (const auto& opt: opts)
        seed ^= hash_fn(opt) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
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
            for (const auto& child: ctx->children) {
                auto is_shared = (ctx->type == context_type::BINARY)
                        ? shared_target::FALSE
                        : shared_target::TRUE;

                switch (child->type) {
                case context_type::SOURCE:
                {
                    auto all_objects = compile_source(ctx,
                                                      child,
                                                      already_processed,
                                                      is_shared);

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

                            return child->without_clopts();
                        }();
                    tests = tests + l->targets(filtered_child);
                    break;
                }

                case context_type::DEFAULT:
                case context_type::BINARY:
                case context_type::LIBRARY:
                case context_type::GENERATE:
                case context_type::HEADER:
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
                   + tests;
        }

        case context_type::TEST:
        {
            auto child_ctx = ctx->dup(context_type::BINARY);
            child_ctx->bin_dir = ctx->obj_dir + "/" + ctx->check_dir;
            auto bin_targets =
                vector_util::filter(
                    vector_util::map(targets(child_ctx),
                                     [](const makefile::target::ptr& t)
                                     {
                                         return t->without(makefile::global_targets::ALL);
                                     }),
                    [](const makefile::target::ptr& t)
                    {
                        return !t->has_global_target(makefile::global_targets::INSTALL);
                    });
            auto bin_name = ctx->type == context_type::BINARY ? ctx->test_binary : bin_targets[0]->name();
            auto deps = std::vector<makefile::target::ptr>{
                            std::make_shared<makefile::target>(bin_name)
                        } + bin_targets;

            auto target_name = ctx->check_dir + "/" + ctx->cmd->data();
            auto short_cmd = "CHECK\t" + ctx->cmd->data();
            auto global_targets = std::vector<makefile::global_targets>{
                makefile::global_targets::CHECK,
                makefile::global_targets::CLEAN
            };
            auto test_name = ctx->obj_dir + "/" + ctx->check_dir + "/" + ctx->cmd->data();
            auto commands = std::vector<std::string>{
                "mkdir -p " + ctx->check_dir,
                "+ptest --test " + test_name + " --out " + target_name + " --bin " + bin_name
            };
            auto comment = std::vector<std::string>{
                "language_cxx::targets() CHECK"
            };
            auto check_target = std::make_shared<makefile::target>(target_name,
                                                                   short_cmd,
                                                                   deps,
                                                                   global_targets,
                                                                   commands,
                                                                   comment);

            return bin_targets + std::vector<makefile::target::ptr>{check_target};
        }

        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::SOURCE:
        case context_type::HEADER:
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
    std::vector<std::string> out;

    std::vector<std::regex> remove_patterns = {
        std::regex("(.*)\\.h"),
#if ((__GNUC__ != 4) || (__GNUC_MINOR__ > 8))
        std::regex("(.*)\\.h\\+\\+")
#endif
    };

    std::vector<std::string> add_patterns = {
        "$1.c++",
        "$1.c"
    };

    const auto regex_flags = std::regex_constants::format_no_copy;
    for (const auto& remove: remove_patterns) {
        for (const auto& add: add_patterns) {
            std::string f = std::regex_replace(full_header_path,
                                               remove,
                                               add,
                                               regex_flags);
            if (access(f.c_str(), R_OK) == 0)
                out.push_back(f);
        }
    }

#if ((__GNUC__ == 4) && (__GNUC_MINOR__ <= 8))
    /* GCC-4.8 has bad regex support, so it drops the ".h++" to ".c++"
     * conversion. */
    {
        auto lpos = full_header_path.find_last_of(".");
        for (const auto& ending: std::vector<std::string>{".c++", ".c"}) {
            if (lpos != std::string::npos) {
                auto f = full_header_path.substr(0, lpos) + ending;
                if (access(f.c_str(), R_OK) == 0)
                    out.push_back(f);
            }
        }
    }
#endif

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
                                       const std::string linker_pretty)
: _target_path(target_path),
  _objects(objects),
  _additional_deps(additional_deps),
  _install(install),
  _shared(shared),
  _comments(comments),
  _opts(opts),
  _ctx(ctx),
  _linker_command(linker_command),
  _linker_pretty(linker_pretty)
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

    auto shared = [&](void) -> std::string
        {
            switch (_shared) {
            case shared_target::TRUE:
                return " -shared";
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
    auto rpath = [&](void) -> std::string
        {
            switch (_install) {
            case install_target::TRUE:
                return "-Wl,-rpath," + _ctx->prefix + "/" + _ctx->lib_dir;
            case install_target::FALSE:
                return "-Wl,-rpath,\\$$ORIGIN/" + dotdot(_ctx->bin_dir) + _ctx->lib_dir;
            }

            abort();
            return "";
        }();

    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        _linker_command
          + " -o" + _target_path
          + " " + vector_util::join(vector_util::map(_objects, target2name), " ")
          + " " + vector_util::join(_opts, " ")
          + " " + shared
          + " " + rpath
    };


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
                                   const target::ptr& source,
                                   const install_target& install,
                                   const std::vector<std::string> comments)
: _target_path(target_path),
  _source(source),
  _install(install),
  _comments(comments)
{
}

makefile::target::ptr
language_cxx::cp_target::generate_makefile_target(void) const
{
    auto deps = vector_util::make(_source->generate_makefile_target());
    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        "cp --reflink=auto -f " + _source->path() + " " + _target_path
    };

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
        std::string("CP\t") + _target_path,
        deps,
        global,
        cmds,
        _comments);
}

language_cxx::header_target::header_target(const std::string& path)
: _path(path)
{
}

makefile::target::ptr
language_cxx::header_target::generate_makefile_target(void) const
{
    return std::make_shared<makefile::target>(_path);
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
 
    auto bin_dir = [&]() -> std::string
        {
            switch (ctx->type) {
            case context_type::BINARY:
                return ctx->bin_dir;
            case context_type::LIBRARY:
                return ctx->lib_dir;
            default: break;
            }
            
            std::cerr << "language_cxx: Internal error\n";
            abort();
            return "";
        }();
        
    auto shared_link_dir =
        ctx->obj_dir
        + "/" + bin_dir
        + "/" + ctx->cmd->data()
        + "/" + hash_link_options(ctx)
        + "/";

    auto all_opts = link_opts() + ctx->link_opts +
        std::vector<std::string>{
            "-L" + ctx->lib_dir,
        } + vector_util::map(ctx->dep_libs, [](std::string dl){ return "-l" + dl; });

    auto additional_deps =
        vector_util::map(ctx->dep_libs,
                         [&](std::string dl) -> target::ptr {
                            return std::make_shared<header_target>(ctx->lib_dir + "/lib" + dl + ".so");
                         });

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
        this->linker_command(),
        this->linker_pretty()
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
        this->linker_command(),
        this->linker_pretty()
    );

    /* In order to keep the local and install targets consistant with the
     * Makefile, we build the "copy" targets that depend on the generated
     * Makefile. */
    auto cp_install_target = std::make_shared<cp_target>(
        "$(DESTDIR)/" + ctx->prefix + "/" + bin_dir + "/" + ctx->cmd->data(),
        install_target,
        language_cxx::install_target::TRUE,
        shared_comments + std::vector<std::string>{"cp_install_target"}
    );

     auto cp_local_target = std::make_shared<cp_target>(
        bin_dir + "/" + ctx->cmd->data(),
        local_target,
        language_cxx::install_target::FALSE,
        shared_comments + std::vector<std::string>{"cp_local_target"}
    );

    /* Here we return all the objects that were generated as part of this
     * linking step: that doesn't include the objects, they're expected to be
     * used elsewhere. */
    return {install_target, local_target, cp_install_target, cp_local_target};
}


std::vector<language_cxx::target::ptr>
language_cxx::compile_source(const context::ptr& ctx,
                             const context::ptr& child,
                             std::vector<std::string>& processed,
                             const shared_target& is_shared)
                             const
{
    auto filter_compile_opts = [&](const std::vector<std::string> compile_opts)
        {
            auto out = std::vector<std::string>();
            for (const auto& opt: compile_opts) {
                if (opt[0] == '-' && opt[1] == 'I' && opt[2] != '/') {
                    out.push_back("-I" + child->src_path + opt.substr(2));
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

    auto shared_link_dir =
        child->obj_dir
        + "/" + ctx->cmd->data()
        + "/" + hash_link_options(ctx)
        + "/";

    auto source_path = child->src_dir + "/" + child->cmd->data();

    auto full_libexec_path = child->prefix + "/" + child->libexec_dir;

    auto compile_opts =
        filter_compile_opts(this->compile_opts()) +
        filter_compile_opts(child->compile_opts) +
        std::vector<std::string>{
            "-I" + child->src_path + child->hdr_dir,
            "-I" + child->hdr_dir,
            "-I" + child->obj_dir + "/proc",
            "-D__PCONFIGURE__LIBEXEC=\\\"" + full_libexec_path + "\\\"",
            "-D__PCONFIGURE__PREFIX=\\\"" + ctx->prefix + "\\\""
        };

    auto shared_comments = std::vector<std::string>{
        std::to_string(child->cmd->debug()),
        "language_cxx::compile_source()",
        "compile_opts: " + vector_util::join(compile_opts, " ")
    };

    auto base_out_name =
        child->obj_dir
        + "/" + child->src_dir
        + "/" + child->cmd->data()
        + "/" + hash_compile_options(child);

    /* Recursively walks the list of targets. */
    std::vector<target::ptr> deps;
    std::vector<target::ptr> header_deps;
    if (ctx->autodeps == true) {
        for (const auto& header_dep: dependencies(source_path,
                                                  is_shared,
                                                  compile_opts)) {
            {
                auto t = std::make_shared<header_target>(header_dep);
                header_deps = header_deps + std::vector<header_target::ptr>{t};
            }

            for (const auto& dep: find_files_for_header(header_dep)) {
                auto dep_out_name =
                    child->obj_dir
                    + "/" + dep
                    + "/" + hash_compile_options(child);

                bool should_process = true;
                for (const auto& p: processed)
                    if (strcmp(p.c_str(), dep_out_name.c_str()) == 0)
                        should_process = false;
                if (should_process == false)
                    continue;
                processed.push_back(dep_out_name);

                std::string stripped_dep = dep.c_str() + child->src_dir.size() + 1;
                auto cmd = std::make_shared<command>(command_type::SOURCES,
                                                     "+=",
                                                     stripped_dep,
                                                     child->cmd->debug());
                auto dep_ctx = child->dup(context_type::SOURCE, cmd, {});

                deps = deps + compile_source(ctx, dep_ctx, processed, is_shared);
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
        this->compiler_command(),
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
        this->compiler_command(),
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

std::vector<std::string> language_cxx::dependencies(
    const std::string& filename,
    const shared_target& is_shared __attribute__((unused)),
    const std::vector<std::string>& compile_opts) const
{
    std::vector<std::string> defined;
    std::vector<std::string> include_dirs;

    for (const auto& opt: compile_opts) {
        if (strncmp(opt.c_str(), "-D", 2) == 0)
            defined.push_back(opt.c_str() + 2);
        if (strncmp(opt.c_str(), "-I", 2) == 0)
            include_dirs.push_back(opt.c_str() + 2);
    }

    std::vector<std::string> all_files;
    pinclude::list(filename,
                   include_dirs,
                   defined,
                   [&](std::string s) {
                       all_files.push_back(s);
                       return 0;
                   },
                   true);

    return all_files;
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
