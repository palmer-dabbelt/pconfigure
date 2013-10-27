
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

#ifndef CLANG_H
#define CLANG_H

#define CLANG_INCLUDE_COUNT 1024
#define CLANG_DEFINE_COUNT 1024

struct CXIndex
{
    /* Here to make pedantic happy. */
    char unused;
};
typedef struct CXIndex *CXIndex;

struct CXTranslationUnit
{
    char *include_path[CLANG_INCLUDE_COUNT];
    char *defines[CLANG_DEFINE_COUNT];
    char *filename;
};
typedef struct CXTranslationUnit *CXTranslationUnit;

struct CXUnsavedFile
{
    /* Here to make pedantic happy. */
    char unused;
};
typedef struct CXUnsavedFile *CXUnsavedFile;

enum CXTranslationUnit_Flags
{
    CXTranslationUnit_None = 0x0
};

struct CXFile
{
    char *filename;
};
typedef struct CXFile *CXFile;

struct CXSourceLocation
{
    /* Here to make pedantic happy. */
    char unused;
};
typedef struct CXSourceLocation *CXSourceLocation;

typedef void *CXClientData;

struct CXString
{
    char *cstr;
};
typedef struct CXString *CXString;

CXIndex clang_createIndex(int excludeDeclarationsFromPCH,
                          int displayDiagnostics);

CXTranslationUnit clang_parseTranslationUnit(CXIndex CIdx,
                                             const char *source_filename,
                                             const char *const *argv,
                                             int argc,
                                             struct CXUnsavedFile *us_files,
                                             unsigned num_unsaved_files,
                                             unsigned options);

typedef void (*CXInclusionVisitor) (CXFile included_file,
                                    CXSourceLocation * inclusion_stack,
                                    unsigned include_len,
                                    CXClientData client_data);

void clang_getInclusions(CXTranslationUnit tu,
                         CXInclusionVisitor visitor,
                         CXClientData client_data);

CXString clang_getFileName(CXFile SFile);

const char *clang_getCString(CXString string);

void clang_disposeString(CXString string);

void clang_disposeTranslationUnit(CXTranslationUnit tu);

void clang_disposeIndex(CXIndex index);

#endif
