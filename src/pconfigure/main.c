
/*
 * Copyright (C) 2011 Palmer Dabbelt
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

#include "clopts.h"
#include "contextstack.h"
#include "languagelist.h"
#include "makefile.h"
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <talloc.h>
#include <unistd.h>

static const unsigned int MAX_LINE_SIZE = 1024;

/* Parses an entire file */
static int parse_file(const char *filename);

/* Splits a line into three parts */
static int parse_line(const char *line, char *left, char *op, char *right);

/* Calls the correct language for a function */
static int parse_select(const char *left, const char *op, char *right);

static int parsefunc_prefix(const char *op, const char *right);
static int parsefunc_languages(const char *op, const char *right);
static int parsefunc_compileopts(const char *op, const char *right);
static int parsefunc_linkopts(const char *op, const char *right);
static int parsefunc_deplibs(const char *op, const char *right);
static int parsefunc_binaries(const char *op, const char *right);
static int parsefunc_libraries(const char *op, const char *right);
static int parsefunc_sources(const char *op, const char *right);
static int parsefunc_config(const char *op, const char *right);

/* This is global data to avoid having really long parsefunc_* function calls */
static struct clopts *o;
static struct makefile *mf;
static struct contextstack *s;
static struct languagelist *ll;

int main(int argc, char **argv)
{
    int i;

    /* talloc initialization, needs to come before any talloc calls */
    talloc_enable_leak_report();
    talloc_set_log_stderr();

    o = clopts_new(argc, argv);
    if (o == NULL)
    {
#ifdef DEBUG
        fprintf(stderr, "Internal error allocating clopts\n");
#endif
        TALLOC_FREE(o);
        return 1;
    }

    mf = makefile_new(o);
    if (mf == NULL)
    {
#ifndef DEBUG
        fprintf(stderr, "Internal error allocating makefile\n");
#endif
        TALLOC_FREE(o);
        return 2;
    }

    ll = languagelist_new(o);
    if (ll == NULL)
    {
#ifndef DEBUG
        fprintf(stderr, "Internal error allocating languagelist\n");
#endif
        TALLOC_FREE(o);
        return 3;
    }

    s = contextstack_new(o, mf, ll);
    if (s == NULL)
    {
#ifndef DEBUG
        fprintf(stderr, "Internal error allocating contextstack\n");
#endif
        TALLOC_FREE(o);
        return 3;
    }

    /* Reads every input file in order */
    for (i = 0; i < o->infile_count; i++)
    {
        if (parse_file(o->infiles[i]) != 0)
        {
            TALLOC_FREE(o);
            break;
        }
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s))
    {
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
    while (fgets(line, MAX_LINE_SIZE, file) != NULL)
    {
        int err;

#ifdef DEBUG
        fprintf(stderr, "%s", line);
#endif

        /* Splits the line into bits */
        err = parse_line(line, left, op, right);
        if (err != 0)
        {
            fprintf(stderr, "Read error %d on line %d of %s:\n\t%s",
                    err, line_num, filename, line);
            return err;
        }

        /* Calls the correct function to parse this input line */
        if (parse_select(left, op, right) != 0)
        {
            fprintf(stderr, "Error parsing line %d:\n", line_num);
            fprintf(stderr, "%s\n", line);
            return -1;
        }

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
    while ((line[line_cur] != '\0') && !isspace(line[line_cur]))
    {
        assert(left_cur < MAX_LINE_SIZE);
        left[left_cur] = line[line_cur];
        left_cur++;
        line_cur++;
    }

    while ((line[line_cur] != '\0') && isspace(line[line_cur]))
        line_cur++;

    while ((line[line_cur] != '\0') && !isspace(line[line_cur]))
    {
        assert(op_cur < MAX_LINE_SIZE);
        op[op_cur] = line[line_cur];
        op_cur++;
        line_cur++;
    }

    while ((line[line_cur] != '\0') && isspace(line[line_cur]))
        line_cur++;

    while (line[line_cur] != '\0')
    {
        assert(right_cur < MAX_LINE_SIZE);
        right[right_cur] = line[line_cur];
        right_cur++;
        line_cur++;
    }

    assert(right_cur != 1);
    right_cur--;

    while ((right_cur > 0) && (isspace(right[right_cur])))
    {
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
    while (i < strlen(right))
    {
        if (right[i] == '`')
        {
            char *tmpname;
            int fd;
            int err;
            char line[MAX_LINE_SIZE];
            FILE *file;

            i++;
            cmdi = 0;
            while (right[i] != '`')
            {
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
            if (err != 0)
            {
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
            while (fgets(line, MAX_LINE_SIZE, file) != NULL)
            {
                i++;
                i += strlen(line);
                if (i >= MAX_LINE_SIZE)
                    abort();

                while (isspace(line[strlen(line) - 1]))
                {
                    line[strlen(line) - 1] = '\0';
                    i--;
                }

                strcat(newright, line);
                strcat(newright, " ");
            }
            newright[strlen(newright) - 1] = '\0';

            close(fd);
            unlink(tmpname);
        }
        else
        {
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
    if (strcmp(left, "PREFIX") == 0)
        return parsefunc_prefix(op, right);
    if (strcmp(left, "LANGUAGES") == 0)
        return parsefunc_languages(op, right);
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
    if (strcmp(left, "SOURCES") == 0)
        return parsefunc_sources(op, right);
    if (strcmp(left, "CONFIG") == 0)
        return parsefunc_config(op, right);

    return -2;
}

int parsefunc_prefix(const char *op, const char *right)
{
    void *context;
    struct context *c;
    const char *duped;
    int err;

    if (strcmp(op, "=") != 0)
    {
        fprintf(stderr, "We only support = for PREFIX\n");
        return -1;
    }

    /* This gets added to the current context stack, even if it's just the
     * default context. */
    context = talloc_new(NULL);
    c = contextstack_peek_default(s, context);
    duped = talloc_strdup(context, right);
    err = context_set_prefix(c, duped);
    TALLOC_FREE(context);

    return err;
}

int parsefunc_languages(const char *op, const char *right)
{
    int err;

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for LANGUAGES\n");
        return -1;
    }

    err = languagelist_select(ll, right);
    if (err != 0)
    {
        fprintf(stderr, "Unable to select language '%s'\n", right);
        return -1;
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

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for COMPILEOPTS\n");
        return -1;
    }

    /* Splits into spaces. */
    start = 0;
    quotes = 0;
    end = 0;
    while ((start < strlen(right)) && (end <= strlen(right)))
    {
        if (right[end] == '\"')
            quotes++;

        if ((isspace(right[end])) && (quotes % 2) == 0)
        {
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
    if (start != 0)
    {
        memset(newright, '\0', MAX_LINE_SIZE);
        strcpy(newright, right + start);
        return parsefunc_compileopts(op, newright);
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s))
    {
        struct language *l;
        char *duped;
        void *context;

        context = talloc_new(NULL);

        l = languagelist_get(ll, context);
        if (l == NULL)
        {
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

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for LINKOPTS\n");
        return -1;
    }

    /* Splits into spaces. */
    start = 0;
    quotes = 0;
    end = 0;
    while ((start < strlen(right)) && (end <= strlen(right)))
    {
        if (right[end] == '\"')
            quotes++;

        if ((isspace(right[end])) && (quotes % 2) == 0)
        {
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
    if (start != 0)
    {
        memset(newright, '\0', MAX_LINE_SIZE);
        strcpy(newright, right + start);
        return parsefunc_linkopts(op, newright);
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s))
    {
        struct language *l;
        char *duped;
        void *context;

        context = talloc_new(NULL);

        l = languagelist_get(ll, context);
        if (l == NULL)
        {
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

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for BINARIES\n");
        return -1;
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s))
    {
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

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for BINARIES\n");
        return -1;
    }

    /* If there's anything left on the stack, then clear everything out */
    while (!contextstack_isempty(s))
    {
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

int parsefunc_sources(const char *op, const char *right)
{
    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for BINARIES\n");
        return -1;
    }

    /* Adds a binary to the stack, using the default compile options.  There is
     * no need for this to  */
    contextstack_push_source(s, right);
    return 0;
}

int parsefunc_config(const char *op, const char *right)
{
    char *filename;
    int out;

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for CONFIG\n");
        return -1;
    }

    filename = talloc_asprintf(s, "Configfiles/%s", right);
    out = parse_file(filename);
    TALLOC_FREE(filename);
    return out;
}

int parsefunc_deplibs(const char *op, const char *right)
{
    struct context *c;
    void *context;
    char *duped;
    int err;

    if (strcmp(op, "+=") != 0)
    {
        fprintf(stderr, "We only support += for DEPLIBS\n");
        return -1;
    }

    /* If the stack is empty, then add this to the language-specific global
     * list of options. */
    if (contextstack_isempty(s))
    {
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
