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
#include <pinclude.h>
#include <unistd.h>
#include <fcntl.h>
#include <iostream>

struct pinclude_priv {
    std::vector<std::string> all_files;
};
static int pinclude_callback(const char *filename, void *priv_uncase);

language_cxx* language_cxx::clone(void) const
{
    return new language_cxx(
        _compiler,
        _linker
    );
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
            break;
    }

    std::cerr << "language_cxx: Internal error in is_shared_target()" << std::endl;
    abort();
}

std::string language_cxx::hash_link_options(const context::ptr& ctx) const
{
    return hash_options(ctx->clopts());
}

std::string language_cxx::hash_compile_options(const context::ptr& ctx) const
{
    return hash_options(ctx->list_compile_opts());
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
            for (const auto& child: ctx->children) {
                auto is_shared = (ctx->type == context_type::BINARY)
                        ? shared_target::FALSE
                        : shared_target::TRUE;

                if (child->type != context_type::SOURCE)
                    continue;

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
            }

            auto link = link_objects(ctx, objects);
            return vector_util::map(objects + link,
                                    [](const target::ptr& t) -> makefile::target::ptr
                                    {
                                        return t->generate_makefile_target();
                                    });
        }

        case context_type::TEST:
        case context_type::DEFAULT:
        case context_type::GENERATE:
        case context_type::SOURCE:
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
        std::regex("(.*)\\.h++")
    };

    std::vector<std::string> add_patterns = {
        "$1.c++",
        "$1.c"
    };

    for (const auto& remove: remove_patterns) {
        for (const auto& add: add_patterns) {
            std::string f = std::regex_replace(full_header_path, remove, add);
            if (access(f.c_str(), R_OK) == 0)
                out.push_back(f);
        }
    }

    return out;
}

language_cxx::link_target::link_target(const std::string& target_path, 
                                       const std::vector<target::ptr>& objects,
                                       const install_target& install,
                                       const shared_target& shared,
                                       const std::vector<std::string>& comments,
                                       const std::vector<std::string>& opts,
                                       const context::ptr& ctx,
                                       const std::string linker)
: _target_path(target_path),
  _objects(objects),
  _install(install),
  _shared(shared),
  _comments(comments),
  _opts(opts),
  _ctx(ctx),
  _linker(linker)
{
}

makefile::target::ptr
language_cxx::link_target::generate_makefile_target(void) const
{
    auto deps = vector_util::map(_objects,
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

    auto cmds = std::vector<std::string>{
        "mkdir -p $(dir $@)",
        _linker
          + " -o" + _target_path
          + " " + vector_util::join(vector_util::map(_objects, target2name), " ")
          + " " + vector_util::join(_opts, " ")
          + shared
    };


    auto global = std::vector<makefile::global_targets>{
        makefile::global_targets::CLEAN,
    };

    return std::make_shared<makefile::target>(
        _target_path,
        _linker + "\t" + _ctx->cmd->data(),
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
                                             const std::string compiler)
: _target_path(target_path),
  _main_source(main_source),
  _shared(shared),
  _comments(comments),
  _opts(opts),
  _ctx(ctx),
  _compiler(compiler)
{
}

makefile::target::ptr
language_cxx::compile_target::generate_makefile_target(void) const
{
    auto deps = std::vector<makefile::target::ptr>{
      std::make_shared<makefile::target>(_main_source)
    };

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
        _compiler
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
        _compiler + "\t" + _ctx->cmd->data(),
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

    /* There's actually two proper targets here: one which generates the link
     * that's targeted for installation, and one that generates the link that's
     * targeted for actual compulation. */
    auto install_target = std::make_shared<link_target>(
        shared_link_dir + "install",
        objects,
        language_cxx::install_target::TRUE,
        is_shared_target(ctx),
        shared_comments + std::vector<std::string>{"install_target"},
        link_opts() + ctx->link_opts,
        ctx,
        _linker
    );

    auto local_target = std::make_shared<link_target>(
        shared_link_dir + "local",
        objects,
        language_cxx::install_target::FALSE,
        is_shared_target(ctx),
        shared_comments + std::vector<std::string>{"local_target"},
        link_opts() + ctx->link_opts,
        ctx,
        _linker
    );

    /* In order to keep the local and install targets consistant with the
     * Makefile, we build the "copy" targets that depend on the generated
     * Makefile. */
    auto cp_install_target = std::make_shared<cp_target>(
        ctx->prefix + "/" + bin_dir + "/" + ctx->cmd->data(),
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
    auto shared_link_dir =
        child->obj_dir
        + "/" + ctx->cmd->data()
        + "/" + hash_link_options(ctx)
        + "/";

    auto source_path = child->src_dir + "/" + child->cmd->data();

    auto full_libexec_path = child->prefix + "/" + child->libexec_dir;

    auto compile_opts = this->compile_opts() + child->compile_opts +
        std::vector<std::string>{
            "-I" + child->hdr_dir,
            "-I" + child->obj_dir + "/proc",
            "-D__PCONFIGURE__LIBEXEC=\\\"" + full_libexec_path + "\\\""
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

    /* There's two targets here: one for staticly linked programs, and ony for
     * dynamically linked ones. */
    auto static_ctarget = std::make_shared<compile_target>(
        base_out_name + "-static.o",
        source_path,
        language_cxx::shared_target::FALSE,
        shared_comments + std::vector<std::string>{"static_target"},
        compile_opts,
        child,
        _compiler
    );

    auto shared_ctarget = std::make_shared<compile_target>(
        base_out_name + "-shared.o",
        source_path,
        language_cxx::shared_target::TRUE,
        shared_comments + std::vector<std::string>{"shared_target"},
        compile_opts,
        child,
        _compiler
    );

    /* Recursively walks the list of targets. */
    std::vector<target::ptr> deps;
    for (const auto& header_dep: dependencies(source_path,
                                              is_shared,
                                              compile_opts)) {
#if 0
        {
            auto t = std::make_shared<header_target>(header_dep);
            deps = deps + std::vector<header_target::ptr>{t};
        }
#endif

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
    size_t defined_i = 0;
    const char **defined = new const char*[compile_opts.size()];
    size_t include_dirs_i = 0;
    const char **include_dirs = new const char*[compile_opts.size()];

    for (const auto& opt: compile_opts) {
        if (strncmp(opt.c_str(), "-D", 2) == 0)
            defined[defined_i++] = opt.c_str() + 2;
        if (strncmp(opt.c_str(), "-I", 2) == 0)
            include_dirs[include_dirs_i++] = opt.c_str() + 2;
    }

    defined[defined_i] = nullptr;
    include_dirs[include_dirs_i] = nullptr;

    struct pinclude_priv priv;
    pinclude_list(filename.c_str(),
                  &pinclude_callback,
                  &priv,
                  &defined[0],
                  &include_dirs[0]);

    delete[] defined;
    delete[] include_dirs;

    return priv.all_files;
}

int pinclude_callback(const char *filename, void *priv_uncast)
{
    struct pinclude_priv *priv = (struct pinclude_priv *)priv_uncast;
    priv->all_files.push_back(filename);
    return 0;
}

static void install_cxx(void) __attribute__((constructor));
void install_cxx(void)
{
    language_list::global_add(
        std::make_shared<language_cxx>(
            "$(CXX)",
            "$(CXX)"
        )
    );
}
