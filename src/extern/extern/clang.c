
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
    const char *hdr;
    int i;

    out = malloc(sizeof(*out));
    out->filename = NULL;
    out->include_path = NULL;

    src = NULL;
    hdr = NULL;
    for (i = 0; i < argc; i++)
    {
        if (strncmp(argv[i], "-I", 2) == 0)
            hdr = argv[i] + 2;

        if (argv[i][0] == '-')
            continue;

        src = argv[i];
    }

    if (src != NULL)
        out->filename = strdup(src);

    if (hdr != NULL)
        out->include_path = strdup(hdr);

    return out;
}

void clang_getInclusions(CXTranslationUnit tu,
                         CXInclusionVisitor visitor, CXClientData client_data)
{
    struct pinclude_visitor_args args;
    char *dirs[2];

    args.visitor = visitor;
    args.client_data = client_data;

    dirs[0] = tu->include_path;
    dirs[1] = NULL;
    pinclude_list(tu->filename, &pinclude_visitor, &args, dirs);
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
    if (tu->filename != NULL)
        free(tu->filename);

    if (tu->include_path != NULL)
        free(tu->include_path);

    free(tu);
}

void clang_disposeIndex(CXIndex index)
{
    free(index);
}
