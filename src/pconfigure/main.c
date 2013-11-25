
/*
 * Copyright (C) 2011,2013 Palmer Dabbelt
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

#define _BSD_SOURCE

#include "clopts.h"
#include "contextstack.h"
#include "generate.h"
#include "languagelist.h"
#include "makefile.h"
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

#define MAX_LINE_SIZE 1024

/* Parses an entire file */
static int parse_file(const char *filename);

/* Splits a line into three parts */
static int parse_line(const char *line, char *left, char *op, char *right);

/* Calls the correct language for a function */
static int parse_select(const char *left, const char *op, char *right);

static int parsefunc_config(const char *op, const char *right);
static int parsefunc_languages(const char *op, const char *right);
static int parsefunc_prefix(const char *op, const char *right);
static int parsefunc_compileopts(const char *op, const char *right);
static int parsefunc_linkopts(const char *op, const char *right);
static int parsefunc_deplibs(const char *op, const char *right);
static int parsefunc_binaries(const char *op, const char *right);
static int parsefunc_libraries(const char *op, const char *right);
static int parsefunc_headers(const char *op, const char *right);
static int parsefunc_sources(const char *op, const char *right);
static int parsefunc_compiler(const char *op, const char *right);
static int parsefunc_linker(const char *op, const char *right);
static int parsefunc_libdir(const char *op, const char *right);
static int parsefunc_tests(const char *op, const char *right);
static int parsefunc_testsrc(const char *op, const char *right);
static int parsefunc_generate(const char *op, const char *right);
static int parsefunc_tgenerate(const char *op, const char *right);
static int parsefunc_testdeps(const char *op, const char *right);

/* This is global data to avoid having really long parsefunc_*
 * function calls. */
struct clopts *o;
static struct makefile *mf;
static struct contextstack *s;
bool found_binary;
void *root_context;

/* FIXME: This is needed by lang/chisel.c, which is a huge hack! */
struct languagelist *ll;

int main(int argc, char **argv)
{
    int i;

    /* talloc initialization, needs to come before any talloc calls */
    talloc_enable_leak_report();
    talloc_set_log_stderr();

    /* Generates a root context, which is used to track all the memory
     * allocated by talloc. */
    root_context = talloc_init("main(): root_context");

    o = clopts_new(root_context, argc, argv);

    /* clopts are NULL when a short print is triggered -- this just
     * cleans up so there isn't a talloc error message. */
    if (o == NULL) {
        TALLOC_FREE(root_context);
        return 0;
    }

    /* Start without having found the binary or the source. */
    found_binary = false;

    mf = makefile_new(o);
    if (mf == NULL) {
#ifndef DEBUG
        fprintf(stderr, "Internal error allocating makefile\n");
#endif
        TALLOC_FREE(o);
        return 2;
    }

    ll = languagelist_new(o);
    if (ll == NULL) {
#ifndef DEBUG
        fprintf(stderr, "Internal error allocating languagelist\n");
#endif
        TALLOC_FREE(o);
        return 3;
    }

    s = contextstack_new(o, mf, ll);
    if (s == NULL) {
#ifndef DEBUG
        fprintf(stderr, "Internal error allocating contextstack\n");
#endif
        TALLOC_FREE(o);
        return 3;
    }

    /* Reads every input file in order */
    for (i = 0; i < o->infile_count; i++) {
        if (parse_file(o->infiles[i]) != 0) {
            TALLOC_FREE(o);
            break;
        }
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s)) {
        void *context;

        context = talloc_new(NULL);

        /* We already know that there is an element on the stack, so there
         * is no need to check for errors. */
        contextstack_pop(s, context);

        /* That's all we need to do, as free()ing the context will cause it to
         * be cleaned up and pushed over to  */
        TALLOC_FREE(context);
    }

    TALLOC_FREE(o);

    /* Remove this and you'll end up with a leak report. */
    TALLOC_FREE(root_context);

    return 0;
}

int parse_file(const char *filename)
{
    FILE *file;
    char line[MAX_LINE_SIZE];
    char left[MAX_LINE_SIZE], op[MAX_LINE_SIZE], right[MAX_LINE_SIZE];
    unsigned int line_num;

    file = fopen(filename, "r");
    if (file == NULL)
        return 0;

    /* Reads the entire file */
    line_num = 1;
    while (fgets(line, MAX_LINE_SIZE, file) != NULL) {
        int err;

#ifdef DEBUG
        fprintf(stderr, "%s", line);
#endif

        /* Skip comments, which are denoted by a '#' on the first line. */
        if ((strlen(line) > 1) && (line[0] == '#'))
            goto cleanup;

        /* Splits the line into bits */
        err = parse_line(line, left, op, right);
        if (err != 0) {
            fprintf(stderr, "Read error %d on line %d of %s:\n\t%s",
                    err, line_num, filename, line);
            return err;
        }

        /* Calls the correct function to parse this input line */
        if (parse_select(left, op, right) != 0) {
            fprintf(stderr, "Error parsing line %d:\n", line_num);
            fprintf(stderr, "%s\n", line);
            return -1;
        }

      cleanup:
        line_num++;
    }

    fclose(file);

    return 0;
}

int parse_line(const char *line, char *left, char *op, char *right)
{
    int line_cur, left_cur, op_cur, right_cur;

    line_cur = left_cur = op_cur = right_cur = 0;
    memset(left, 0, MAX_LINE_SIZE);
    memset(op, 0, MAX_LINE_SIZE);
    memset(right, 0, MAX_LINE_SIZE);

    /* Removes all leading whitespace */
    while ((line[line_cur] != '\0') && isspace(line[line_cur]))
        line_cur++;

    /* Splits into 3 parts */
    while ((line[line_cur] != '\0') && !isspace(line[line_cur])) {
        assert(left_cur < (int)MAX_LINE_SIZE);
        left[left_cur] = line[line_cur];
        left_cur++;
        line_cur++;
    }

    while ((line[line_cur] != '\0') && isspace(line[line_cur]))
        line_cur++;

    while ((line[line_cur] != '\0') && !isspace(line[line_cur])) {
        assert(op_cur < (int)MAX_LINE_SIZE);
        op[op_cur] = line[line_cur];
        op_cur++;
        line_cur++;
    }

    while ((line[line_cur] != '\0') && isspace(line[line_cur]))
        line_cur++;

    while (line[line_cur] != '\0') {
        assert(right_cur < (int)MAX_LINE_SIZE);
        right[right_cur] = line[line_cur];
        right_cur++;
        line_cur++;
    }

    assert(right_cur != 1);
    right_cur--;

    while ((right_cur > 0) && (isspace(right[right_cur]))) {
        right[right_cur] = '\0';
        right_cur--;
    }

    /* I suppose we always succeed? */
    return 0;
}

int parse_select(const char *left, const char *op, char *right)
{
    char newright[MAX_LINE_SIZE];
    char command[MAX_LINE_SIZE * 2];
    void *context;
    size_t newi, i, cmdi;

    context = talloc_new(NULL);

    memset(newright, '\0', MAX_LINE_SIZE);
    newi = i = cmdi = 0;
    while (i < strlen(right)) {
        if (right[i] == '`') {
            char *tmpname;
            int fd;
            int err;
            char line[MAX_LINE_SIZE];
            FILE *file;

            i++;
            cmdi = 0;
            while (right[i] != '`') {
                command[cmdi] = right[i];
                cmdi++;
                i++;
            }
            command[cmdi] = '\0';
            i++;

            tmpname = talloc_strdup(context, "/tmp/pconfigure.XXXXXX");
            fd = mkstemp(tmpname);
            strcat(command, " > ");
            strcat(command, tmpname);

            err = system(command);
            if (err != 0) {
                int index;
                char old;

                index = strlen(command) - strlen(tmpname) - 3;
                old = command[index];
                command[index] = '\0';
                fprintf(stderr,
                        "Command '%s' failed, which is probably bad\n",
                        command);
                command[index] = old;
            }

            file = fopen(tmpname, "r");
            while (fgets(line, MAX_LINE_SIZE, file) != NULL) {
                i++;
                i += strlen(line);
                if (i >= MAX_LINE_SIZE)
                    abort();

                while (isspace(line[strlen(line) - 1])) {
                    line[strlen(line) - 1] = '\0';
                    i--;
                }

                strcat(newright, line);
                strcat(newright, " ");
            }
            newright[strlen(newright) - 1] = '\0';

            close(fd);
            unlink(tmpname);
        } else {
            newright[newi] = right[i];
            newi++;
            i++;
        }
    }

    strcpy(right, newright);

    TALLOC_FREE(context);

    /* Calls the correct function to parse this input line */
    if (strlen(left) == 0)
        return 0;
    if (strcmp(left, "CONFIG") == 0)
        return parsefunc_config(op, right);
    if (strcmp(left, "LANGUAGES") == 0)
        return parsefunc_languages(op, right);
    if (strcmp(left, "PREFIX") == 0)
        return parsefunc_prefix(op, right);
    if (strcmp(left, "COMPILEOPTS") == 0)
        return parsefunc_compileopts(op, right);
    if (strcmp(left, "LINKOPTS") == 0)
        return parsefunc_linkopts(op, right);
    if (strcmp(left, "DEPLIBS") == 0)
        return parsefunc_deplibs(op, right);
    if (strcmp(left, "BINARIES") == 0)
        return parsefunc_binaries(op, right);
    if (strcmp(left, "LIBRARIES") == 0)
        return parsefunc_libraries(op, right);
    if (strcmp(left, "HEADERS") == 0)
        return parsefunc_headers(op, right);
    if (strcmp(left, "SOURCES") == 0)
        return parsefunc_sources(op, right);
    if (strcmp(left, "COMPILER") == 0)
        return parsefunc_compiler(op, right);
    if (strcmp(left, "LINKER") == 0)
        return parsefunc_linker(op, right);
    if (strcmp(left, "LIBDIR") == 0)
        return parsefunc_libdir(op, right);
    if (strcmp(left, "TESTS") == 0)
        return parsefunc_tests(op, right);
    if (strcmp(left, "TESTSRC") == 0)
        return parsefunc_testsrc(op, right);
    if (strcmp(left, "GENERATE") == 0)
        return parsefunc_generate(op, right);
    if (strcmp(left, "TGENERATE") == 0)
        return parsefunc_tgenerate(op, right);
    if (strcmp(left, "TESTDEPS") == 0)
        return parsefunc_testdeps(op, right);

    return -2;
}

int parsefunc_prefix(const char *op, const char *right)
{
    void *context;
    struct context *c;
    char *duped;
    int err;
    char *cmd;

    if (strcmp(op, "=") != 0) {
        fprintf(stderr, "We only support = for PREFIX\n");
        return -1;
    }

    /* This gets added to the current context stack, even if it's just the
     * default context. */
    context = talloc_new(NULL);
    c = contextstack_peek_default(s, context);
    duped = talloc_strdup(context, right);
    err = context_set_prefix(c, duped);

    /* Make the necessary directories. */
    cmd = talloc_asprintf(context, "mkdir -p $D%s/%s", c->prefix, c->bin_dir);
    makefile_add_install(mf, cmd);
    cmd = talloc_asprintf(context, "mkdir -p $D%s/%s", c->prefix, c->lib_dir);
    makefile_add_install(mf, cmd);
    cmd = talloc_asprintf(context, "mkdir -p $D%s/%s", c->prefix, c->hdr_dir);
    makefile_add_install(mf, cmd);

    TALLOC_FREE(context);

    return err;
}

int parsefunc_languages(const char *op, const char *right)
{
    int err;
    void *context;

    if (strcmp(op, "+=") != 0 && strcmp(op, "-=") != 0) {
        fprintf(stderr, "We only support [+=,-=] for LANGUAGES\n");
        return -1;
    }

    if (strcmp(op, "+=") == 0) {
        err = languagelist_select(ll, right);
        if (err != 0) {
            fprintf(stderr, "Unable to select language '%s'\n", right);
            return -1;
        }
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s)) {
        context = talloc_new(NULL);

        /* We already know that there is an element on the stack, so there
         * is no need to check for errors. */
        contextstack_pop(s, context);

        /* That's all we need to do, as free()ing the context will cause it to
         * be cleaned up and pushed over to  */
        TALLOC_FREE(context);
    }

    if (strcmp(op, "-=") == 0) {
        err = languagelist_remove(ll, right);
        if (err != 0) {
            fprintf(stderr, "Unable to remove language '%s'\n", right);
            return -1;
        }
    }

    return 0;
}

int parsefunc_compileopts(const char *op, const char *right)
{
    struct context *c;
    void *context;
    const char *duped;
    int err;
    char newright[MAX_LINE_SIZE];
    size_t start, end;
    int quotes;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for COMPILEOPTS\n");
        return -1;
    }

    /* Splits into spaces. */
    start = 0;
    quotes = 0;
    end = 0;
    while ((start < strlen(right)) && (end <= strlen(right))) {
        if (right[end] == '\"')
            quotes++;

        if ((isspace(right[end])) && (quotes % 2) == 0) {
            int err;

            memset(newright, '\0', MAX_LINE_SIZE);
            strncpy(newright, right + start, end - start);

            err = parsefunc_compileopts(op, newright);
            if (err != 0)
                return err;

            while (isspace(right[end]))
                end++;

            start = end;
        }

        end++;
    }
    if (start != 0) {
        memset(newright, '\0', MAX_LINE_SIZE);
        strcpy(newright, right + start);
        return parsefunc_compileopts(op, newright);
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s)) {
        struct language *l;
        char *duped;
        void *context;

        context = talloc_new(NULL);

        l = languagelist_get(ll, context);
        if (l == NULL) {
            fprintf(stderr, "No last language\n");
            TALLOC_FREE(context);
            return -1;
        }

        duped = talloc_strdup(context, right);
        language_add_compileopt(l, duped);
        TALLOC_FREE(context);

        return 0;
    }

    /* The context stack isn't empty, so instead change the options of the 
     * current top-of-stack. */
    context = talloc_new(NULL);
    c = contextstack_peek(s, context);
    duped = talloc_strdup(context, right);
    err = context_add_compileopt(c, duped);
    TALLOC_FREE(context);
    return err;
}

int parsefunc_linkopts(const char *op, const char *right)
{
    struct context *c;
    void *context;
    const char *duped;
    int err;
    char newright[MAX_LINE_SIZE];
    size_t start, end;
    int quotes;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for LINKOPTS\n");
        return -1;
    }

    /* Splits into spaces. */
    start = 0;
    quotes = 0;
    end = 0;
    while ((start < strlen(right)) && (end <= strlen(right))) {
        if (right[end] == '\"')
            quotes++;

        if ((isspace(right[end])) && (quotes % 2) == 0) {
            int err;

            memset(newright, '\0', MAX_LINE_SIZE);
            strncpy(newright, right + start, end - start);

            err = parsefunc_linkopts(op, newright);
            if (err != 0)
                return err;

            while (isspace(right[end]))
                end++;

            start = end;
        }

        end++;
    }
    if (start != 0) {
        memset(newright, '\0', MAX_LINE_SIZE);
        strcpy(newright, right + start);
        return parsefunc_linkopts(op, newright);
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s)) {
        struct language *l;
        char *duped;
        void *context;

        context = talloc_new(NULL);

        l = languagelist_get(ll, context);
        if (l == NULL) {
            fprintf(stderr, "No last language\n");
            TALLOC_FREE(context);
            return -1;
        }

        duped = talloc_strdup(context, right);
        language_add_linkopt(l, duped);
        TALLOC_FREE(context);

        return 0;
    }

    /* The context stack isn't empty, so instead change the options of the 
     * current top-of-stack. */
    context = talloc_new(NULL);
    c = contextstack_peek(s, context);
    duped = talloc_strdup(context, right);
    err = context_add_linkopt(c, duped);
    TALLOC_FREE(context);
    return err;
}

int parsefunc_binaries(const char *op, const char *right)
{
    void *context;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for BINARIES\n");
        return -1;
    }

    /* If we're searching for a binary and this isn't it then just
     * give up. */
    if (o->binname != NULL) {
        if (strcmp(right, o->binname) == 0)
            found_binary = true;
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s)) {
        context = talloc_new(NULL);

        /* We already know that there is an element on the stack, so there
         * is no need to check for errors. */
        contextstack_pop(s, context);

        /* That's all we need to do, as free()ing the context will cause it to
         * be cleaned up and pushed over to  */
        TALLOC_FREE(context);
    }

    /* Adds a binary to the stack, using the default compile options.  There is
     * no need for this to  */
    contextstack_push_binary(s, right);
    return 0;
}

int parsefunc_libraries(const char *op, const char *right)
{
    void *context;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for BINARIES\n");
        return -1;
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s)) {
        context = talloc_new(NULL);

        /* We already know that there is an element on the stack, so there
         * is no need to check for errors. */
        contextstack_pop(s, context);

        /* That's all we need to do, as free()ing the context will cause it to
         * be cleaned up and pushed over to  */
        TALLOC_FREE(context);
    }

    /* Adds a binary to the stack, using the default compile options.  There is
     * no need for this to  */
    contextstack_push_library(s, right);
    return 0;
}

int parsefunc_headers(const char *op, const char *right)
{
    void *context;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for HEADERS\n");
        return -1;
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s)) {
        context = talloc_new(NULL);

        /* We already know that there is an element on the stack, so there
         * is no need to check for errors. */
        contextstack_pop(s, context);

        /* That's all we need to do, as free()ing the context will cause it to
         * be cleaned up and pushed over to  */
        TALLOC_FREE(context);
    }

    /* Adds a binary to the stack, using the default compile options.  There is
     * no need for this to  */
    contextstack_push_header(s, right);
    return 0;
}

int parsefunc_sources(const char *op, const char *right)
{
    void *context;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for BINARIES\n");
        return -1;
    }

    /* Clear out all the sources (but not the libraries or binaries) */
    while (!contextstack_isempty(s)) {
        struct context *c;

        context = talloc_new(NULL);

        /* We already know that there is an element on the stack, so there
         * is no need to check for errors. */
        c = contextstack_peek(s, context);

        if (c->type != CONTEXT_TYPE_SOURCE) {
            TALLOC_FREE(context);
            break;
        }

        contextstack_pop(s, context);
        TALLOC_FREE(context);
    }

    /* Adds the requested source to the compile stack. */
    contextstack_push_source(s, right);

    return 0;
}

int parsefunc_config(const char *op, const char *right)
{
    char *filename;
    int out;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for CONFIG\n");
        return -1;
    }

    filename = talloc_asprintf(s, "Configfiles/%s", right);

    if (access(filename, R_OK) != 0) {
        fprintf(stderr, "Unable to open CONFIG '%s'\n", filename);
        return 1;
    }

    out = parse_file(filename);
    TALLOC_FREE(filename);

    if (mf->opts->verbose)
        fprintf(stderr, "CONFIG += '%s'\n", right);

    return out;
}

int parsefunc_deplibs(const char *op, const char *right)
{
    struct context *c;
    void *context;
    char *duped;
    int err;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for DEPLIBS\n");
        return -1;
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s)) {
        fprintf(stderr, "LIBS += called with an empty context\n");
        return -1;
    }

    /* The context stack isn't empty, so instead change the options of the
     * current top-of-stack. */
    context = talloc_new(NULL);
    c = contextstack_peek(s, context);
    duped = talloc_strdup(context, right);
    err = context_add_library(c, duped);
    TALLOC_FREE(context);
    return err;
}

int parsefunc_compiler(const char *op, const char *right)
{
    int err;

    if (contextstack_isempty(s)) {
        struct language *l;
        char *duped;
        void *context;

        context = talloc_new(NULL);

        l = languagelist_get(ll, context);
        if (l == NULL) {
            fprintf(stderr, "No last language\n");
            TALLOC_FREE(context);
            return -1;
        }

        duped = talloc_strdup(context, right);
        err = language_set_compiler(l, duped);
        TALLOC_FREE(context);

        return err;
    }

    fprintf(stderr, "COMPILER must be passed to a language\n");
    return 1;
}

int parsefunc_linker(const char *op, const char *right)
{
    int err;

    if (contextstack_isempty(s)) {
        struct language *l;
        char *duped;
        void *context;

        context = talloc_new(NULL);

        l = languagelist_get(ll, context);
        if (l == NULL) {
            fprintf(stderr, "No last language\n");
            TALLOC_FREE(context);
            return -1;
        }

        duped = talloc_strdup(context, right);
        err = language_set_linker(l, duped);
        TALLOC_FREE(context);

        return err;
    }

    fprintf(stderr, "LINKER must be passed to a language\n");
    return 1;
}

int parsefunc_libdir(const char *op, const char *right)
{
    if (!contextstack_isempty(s)) {
        fprintf(stderr, "LIBDIR must be passed at the start\n");
        return 1;
    }

    contextstack_set_default_lib_dir(s, right);
    return 0;
}

int parsefunc_tests(const char *op, const char *right)
{
    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for TESTS\n");
        return -1;
    }

    if (o->testname != NULL) {
        if (strcmp(o->testname, right) == 0)
            found_binary = true;
    }

    /* We actually want to clear _almost_ everything on the stack,
     * just everything up to and including the binary. */
    while (!contextstack_isempty(s)) {
        void *context;
        enum context_type type;

        /* Peek at the head of the stack, grabbing its type */
        context = talloc_new(NULL);
        type = contextstack_peek(s, context)->type;
        TALLOC_FREE(context);

        /* We don't want to push that last binary because it's needed
         * by the test cases in order to run against said binary. */
        if (type == CONTEXT_TYPE_BINARY || type == CONTEXT_TYPE_LIBRARY)
            goto push_test;

        /* Actually pop the stack here */
        context = talloc_new(NULL);
        contextstack_pop(s, context);
        TALLOC_FREE(context);
    }

  push_test:
    /* Adds a binary to the stack, using the default compile options.  There is
     * no need for this to  */
    contextstack_push_test(s, right);
    return 0;
}

int parsefunc_testsrc(const char *op, const char *right)
{
    int err;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for TESTS and SOURCES\n");
        return -1;
    }

    if ((err = parsefunc_tests(op, right)) != 0)
        return err;

    return parsefunc_sources(op, right);
}

int parsefunc_generate(const char *op, const char *right)
{
    void *ctx;
    struct context *c;

    /* Don't call generate if --binname or --srcname was passed as
     * it's expected that these sorts of calls come from generate
     * scripts, expected that they won't generate any output, and not
     * necessary to call generate because it won't change the object
     * name anyway. */
    if ((o->binname != NULL) || (o->srcname != NULL))
        return 0;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for GENERATE\n");
        return -1;
    }

    ctx = talloc_new(NULL);
    c = context_new_defaults(o, ctx, mf, ll, s);
    generate(right, c->src_dir, c, mf);
    TALLOC_FREE(ctx);

    return 0;
}

int parsefunc_tgenerate(const char *op, const char *right)
{
    void *ctx;
    struct context *c;

    /* Don't call generate if --binname or --srcname was passed as
     * it's expected that these sorts of calls come from generate
     * scripts, expected that they won't generate any output, and not
     * necessary to call generate because it won't change the object
     * name anyway. */
    if ((o->binname != NULL) || (o->srcname != NULL))
        return 0;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for GENERATE\n");
        return -1;
    }

    ctx = talloc_new(NULL);
    c = context_new_defaults(o, ctx, mf, ll, s);
    generate(right, c->tst_dir, c, mf);
    TALLOC_FREE(ctx);

    return 0;
}

int parsefunc_testdeps(const char *op, const char *right)
{
    struct context *c;
    void *context;
    char *duped;
    int err;

    if (strcmp(op, "+=") != 0) {
        fprintf(stderr, "We only support += for TESTDEPS\n");
        return -1;
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s)) {
        fprintf(stderr, "TESTDEPS += called with an empty context\n");
        return -1;
    }

    /* The context stack isn't empty, so instead change the options of the
     * current top-of-stack. */
    context = talloc_new(NULL);
    c = contextstack_peek(s, context);
    duped = talloc_strdup(context, right);
    err = context_add_testdep(c, duped);
    TALLOC_FREE(context);
    return err;
}
