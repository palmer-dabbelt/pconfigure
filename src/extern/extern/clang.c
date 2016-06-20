
/*
 * Copyright (C) 2013 Palmer Dabbelt
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

#define _GNU_SOURCE

#include "clang.h"

#include <pinclude.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct pinclude_visitor_args
{
    CXInclusionVisitor visitor;
    void *client_data;
};

static int pinclude_visitor(const char *filename, void *priv);

CXIndex clang_createIndex(int excludeDeclarationsFromPCH,
                          int displayDiagnostics)
{
    CXIndex out;

    out = malloc(sizeof(*out));

    return out;
}

CXTranslationUnit clang_parseTranslationUnit(CXIndex CIdx,
                                             const char *source_filename,
                                             const char *const *argv,
                                             int argc,
                                             struct CXUnsavedFile * us_files,
                                             unsigned num_unsaved_files,
                                             unsigned options)
{
    CXTranslationUnit out;
    const char *src;
    int i;
    int hdr_i;
    int def_i;

    out = malloc(sizeof(*out));
    out->filename = NULL;

    for (i = 0; i < CLANG_INCLUDE_COUNT; i++)
        out->include_path[i] = NULL;

    for (i = 0; i < CLANG_DEFINE_COUNT; i++)
        out->defines[i] = NULL;

    src = NULL;
    hdr_i = 0;
    def_i = 0;
    for (i = 0; i < argc; i++) {
        if (strncmp(argv[i], "-I", 2) == 0)
            out->include_path[hdr_i++] = strdup(argv[i] + 2);
        if (strncmp(argv[i], "-D", 2) == 0)
            out->defines[def_i++] = strdup(argv[i] + 2);

        if (argv[i][0] == '-')
            continue;

        if (strlen(argv[i]) > 0)
            src = argv[i];
    }

    if (src != NULL)
        out->filename = strdup(src);

    return out;
}

void clang_getInclusions(CXTranslationUnit tu,
                         CXInclusionVisitor visitor, CXClientData client_data)
{
    struct pinclude_visitor_args args;
    char *dirs[CLANG_INCLUDE_COUNT + 1];
    char *defs[CLANG_INCLUDE_COUNT + 1];
    struct CXFile source_file;
    int i;

    args.visitor = visitor;
    args.client_data = client_data;

    source_file.filename = strdup(tu->filename);
    visitor(&source_file, NULL, 0, client_data);
    free(source_file.filename);

    for (i = 0; i < CLANG_INCLUDE_COUNT; i++)
        dirs[i] = tu->include_path[i];
    dirs[i] = NULL;

    for (i = 0; i < CLANG_DEFINE_COUNT; i++)
        defs[i] = tu->defines[i];
    defs[i] = NULL;

    pinclude_list(tu->filename, &pinclude_visitor, &args, (const char **)dirs, (const char **)defs, 1);
}

static int pinclude_visitor(const char *filename, void *priv)
{
    struct pinclude_visitor_args *args;
    struct CXFile included_file;

    args = priv;

    included_file.filename = strdup(filename);

    args->visitor(&included_file, NULL, 0, args->client_data);

    free(included_file.filename);

    return 0;
}

CXString clang_getFileName(CXFile file)
{
    CXString out;

    out = malloc(sizeof(*out));
    out->cstr = strdup(file->filename);

    return out;
}

const char *clang_getCString(CXString string)
{
    return string->cstr;
}

void clang_disposeString(CXString string)
{
    free(string->cstr);
    free(string);
}

void clang_disposeTranslationUnit(CXTranslationUnit tu)
{
    int i;

    if (tu->filename != NULL)
        free(tu->filename);

    for (i = 0; i < CLANG_INCLUDE_COUNT; i++)
        if (tu->include_path[i] != NULL)
            free(tu->include_path[i]);

    free(tu);
}

void clang_disposeIndex(CXIndex index)
{
    free(index);
}
