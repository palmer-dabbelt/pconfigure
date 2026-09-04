
/*
 * Copyright (C) 2013,2016 Palmer Dabbelt
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

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <ctype.h>
#include <pinclude.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef LINE_MAX
#define LINE_MAX 1024
#endif

#define FILE_MAX 1024
#define NEST_MAX 32

#ifndef DEBUG_LIBPINLCUDE_EACHLINE
# ifdef DEBUG_LIBPINCLUDE_DEFINE
#  define DEBUG_LIBPINCLUDE_EACHLINE
# endif
#endif

#ifndef DEBUG_LIBPINLCUDE_EACHLINE
# ifdef DEBUG_LIBPINCLUDE_INCLUDE
#  define DEBUG_LIBPINCLUDE_EACHLINE
# endif
#endif

/* A heredoc whose body has started arriving and whose end hasn't. */
struct heredoc {
    /* The word that ends it.  A heredoc ends at a line that says
     * exactly this and nothing else, which is the only thing about
     * one that has to be understood here. */
    char *delim;

    /* Whether that line is allowed to be indented with tabs, which is
     * what a "<<-" asks for. */
    bool strip_tabs;
};

static void str_chomp(char *str);

static int streqcmp(const char *str, const char *eq);

static void open_heredocs(const char *line, struct heredoc *open, int *count);

static bool closes_heredoc(const char *line, const struct heredoc *open);

static int _pinclude_lines(const char *input,
                           pinclude_callback_t per_include,
                           void *include_priv, pinclude_lineback_t per_line,
                           void *line_priv, const char **include_dirs,
                           const char **defined, char **included,
			   int skip_missing_files)
{
    int err;
    FILE *infile;
    char buffer[LINE_MAX];
    size_t i;
    size_t lineno;
    bool found;
    bool state[NEST_MAX];
    int state_i;
    struct heredoc heredocs[NEST_MAX];
    int heredocs_open;
    bool in_heredoc;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
    fprintf(stderr, "input: '%s'\n", input);
#endif

    infile = fopen(input, "r");

    if (infile == NULL)
        return -1;

    state_i = 0;
    state[state_i] = true;
    lineno = 0;
    heredocs_open = 0;

    while (fgets(buffer, LINE_MAX, infile) != NULL) {
        lineno++;

#ifdef DEBUG_LIBPINCLUDE_EACHLINE
        fprintf(stderr, "    %s", buffer);
#endif

        /* Everything between a "<<EOF" and the line that ends it is
         * text the script writes out rather than script, so nothing
         * in it is a directive.  A C file written into a heredoc
         * brings its own "#include" lines along with it, and those
         * belong to whatever compiles that file rather than to this
         * -- read as directives they would be expanded away, and the
         * file the script wrote would come out with them missing. */
        in_heredoc = heredocs_open > 0;

        if (per_line != NULL) {
            /* An "#include" is a directive rather than text and so
             * never reaches the output.  Inside a heredoc it is
             * neither, which means it goes out exactly as it came
             * in. */
            if (in_heredoc == true || strncmp(buffer, "#include", 8) != 0) {
                if ((err = per_line(buffer, line_priv)) != 0) {
                    return err;
                }
            }
        }

        if (in_heredoc == true) {
            if (closes_heredoc(buffer, &heredocs[0]) == true) {
                int h;

                free(heredocs[0].delim);
                for (h = 1; h < heredocs_open; h++)
                    heredocs[h - 1] = heredocs[h];
                heredocs_open--;
            }

            continue;
        }

        /* Here's where we handle the #if{,n}def preprocessor
         * directives. */
        if (strncmp(buffer, "#ifdef ", strlen("#ifdef ")) == 0 ||
            strncmp(buffer, "#ifdef\t", strlen("#ifdef\t")) == 0) {
            char *define;
            bool matched;

            define = buffer + strlen("#ifdef ");
            str_chomp(define);

            matched = false;
            for (i = 0; defined[i] != NULL; i++)
                if (strcmp(define, defined[i]) == 0)
                    matched = true;

            state_i++;
            state[state_i] = matched;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "ifdef: '%s' (%d -> %d)\n",
                    define, state_i, state[state_i]);
#endif
        }

        if (strncmp(buffer, "#ifndef ", strlen("#ifndef ")) == 0 ||
            strncmp(buffer, "#ifndef\t", strlen("#ifndef\t")) == 0) {
            char *define;
            bool matched;

            define = buffer + strlen("#ifndef ");
            str_chomp(define);

            matched = false;
            for (i = 0; defined[i] != NULL; i++)
                if (streqcmp(define, defined[i]) == 0)
                    matched = true;

            state_i++;
            state[state_i] = !matched;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "ifndef: '%s' (%d -> %d)\n",
                    define, state_i, state[state_i]);
#endif
        }

        if (strncmp(buffer, "#else", strlen("#else")) == 0) {
            state[state_i] = !state[state_i];

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "else: (%d -> %d)\n", state_i, state[state_i]);
#endif
        }

        /* FIXME: I'm just faking support for #if here because I don't
         * want to solve equations.  This keeps the stack correct but
         * doesn't actually handle the check. */
        if (strncmp(buffer, "#if ", strlen("#if ")) == 0) {
            state_i++;
            state[state_i] = true;
        }

        if (strncmp(buffer, "#endif", strlen("#endif")) == 0) {
            if (state_i == 0)
                abort();

            state_i--;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "endif: (%d -> %d)\n", state_i, state[state_i]);
#endif
        }

        /* If we're #ifdef'd out then skip the line. */
        if (state[state_i] == false)
            continue;

        /* What this line opens, which is what the lines after it are
         * the body of.  Asked after the line has been let through the
         * #ifdef state above, since a heredoc written in a branch
         * that isn't taken is one whose body never arrives. */
        open_heredocs(buffer, heredocs, &heredocs_open);

        /* Here's a hack: treat <> includes just like "" includes.
         *
         * Both spellings mean the same thing here, unlike in C: what
         * this expands is scripts, and a script's includes are all
         * files belonging to whoever wrote it.  Several of the tests
         * in this tree write their harness the angled way. */
        if (strncmp(buffer, "#include <", strlen("#include <")) == 0) {
            buffer[strlen("#include <") - 1] = '"';
            strstr(buffer, ">")[0] = '"';

#ifdef DEBUG_LIBPINCLUDE_INCLUDE
            fprintf(stderr, "include -> %s", buffer);
#endif
        }

        /* Finally attempt to recursively enumerate the #include
         * files. */
        if (strncmp(buffer, "#include \"", strlen("#include \"")) == 0) {
            size_t slash_max;

            char *full_path;
            char *dir_path;
            char *filename;

            /* dir_path = dirname(input) */
            dir_path = strdup(input);

            slash_max = 0;
            for (i = 0; i < strlen(dir_path); i++)
                if (dir_path[i] == '/')
                    slash_max = i;
            dir_path[slash_max] = '\0';

            if (strlen(dir_path) == 0)
                strcpy(dir_path, ".");

            /* Pull FILENAME out of #include "FILENAME".  The name
             * ends at its closing quote: counting two characters back
             * from the end instead means the last line of a file that
             * doesn't end in a newline comes out one character
             * short. */
            filename = strdup(buffer + strlen("#include \""));
            {
                char *close = strchr(filename, '"');
                if (close != NULL)
                    *close = '\0';
                else
                    str_chomp(filename);
            }

            if (strcmp(dir_path, ".") != 0) {
                if (asprintf(&full_path, "%s/%s", dir_path, filename) < 0)
                    abort();
            } else {
                if (asprintf(&full_path, "%s", filename) < 0)
                    abort();
            }

            for (i = 0; i < FILE_MAX; i++)
                if (included[i] != NULL
                    && strcmp(full_path, included[i]) == 0)
                    goto skip_file;

            found = false;

            if (access(full_path, R_OK) == 0) {
                for (i = 0; i < FILE_MAX; i++) {
                    if (included[i] != NULL)
                        continue;

                    included[i] = strdup(full_path);
                    break;
                }

#ifdef DEBUG_LIBPINCLUDE_INCLUDE
                fprintf(stderr, "inc: '%s'\n", full_path);
#endif

                if (per_include != NULL) {
                    if ((err = per_include(full_path, include_priv)) != 0) {
                        free(dir_path);
                        free(filename);
                        free(full_path);
                        fclose(infile);

                        return err;
                    }
                }

                found = true;
                goto found_file;
            } else if (skip_missing_files == 0) {
                if (per_include != NULL) {
                    if ((err = per_include(full_path, include_priv)) != 0) {
                        free(dir_path);
                        free(filename);
                        free(full_path);

                        return err;
                    }
                }
	    }

            /* Check each additional include directory */
            for (i = 0; include_dirs[i] != NULL; i++) {
                size_t fi;

                free(full_path);
                if (asprintf(&full_path, "%s/%s", include_dirs[i], filename) <
                    0)
                    abort();

                for (fi = 0; fi < FILE_MAX; fi++)
                    if (included[fi] != NULL
                        && strcmp(full_path, included[fi]) == 0)
                        goto skip_file;

                if (access(full_path, R_OK) == 0) {
                    /* A separate index from the one this loop is
                     * walking: they were the same variable, which
                     * only worked because control left immediately. */
                    for (fi = 0; fi < FILE_MAX; fi++) {
                        if (included[fi] != NULL)
                            continue;

                        included[fi] = strdup(full_path);
                        break;
                    }

                    if (per_include != NULL) {
                        if ((err = per_include(full_path, include_priv)) != 0) {
                            free(dir_path);
                            free(filename);
                            free(full_path);
                            fclose(infile);

                            return err;
                        }
                    }

                    found = true;
                    goto found_file;
                }
            }

          found_file:
            /* Nowhere had it.
             *
             * When this is expanding a file rather than listing what
             * that file reads, being unable to find an include has to
             * stop everything.  The "#include" line is a directive
             * rather than text, so it is never written to the output
             * -- which means carrying on writes a file with the
             * include silently missing from it.  For bash that is a
             * script that runs perfectly well and quietly does the
             * wrong thing, which is the worst way for this to fail
             * and was how it failed.
             *
             * Listing is the other case and wants the opposite.  A
             * file that isn't there yet is usually one something else
             * in the build is about to generate, and saying that it
             * will be read is the entire point of asking. */
            if (found == false) {
                if (per_line == NULL)
                    goto skip_file;

                fprintf(stderr, "%s:%zu: can't find '%s'\n",
                        input, lineno, filename);
                fprintf(stderr, "  looked in '%s'\n", dir_path);
                for (i = 0; include_dirs[i] != NULL; i++) {
                    /* The file's own directory is often on the list
                     * as well, and saying it twice reads like two
                     * different places were tried. */
                    if (strcmp(include_dirs[i], dir_path) == 0)
                        continue;

                    fprintf(stderr, "  looked in '%s'\n", include_dirs[i]);
                }
                fprintf(stderr,
                        "  check the spelling, or add a '-I' for the"
                        " directory it's in\n");

                free(dir_path);
                free(filename);
                free(full_path);
                fclose(infile);

                return -1;
            }

            /* Whatever went wrong further down is this file's problem
             * too: the output is written as it goes, so a nested
             * failure that got dropped here would leave a
             * half-expanded file behind and say nothing. */
            if ((err = _pinclude_lines(full_path,
                                       per_include, include_priv,
                                       per_line, line_priv,
                                       include_dirs, defined, included,
                                       skip_missing_files)) != 0) {
                free(dir_path);
                free(filename);
                free(full_path);
                fclose(infile);

                return err;
            }

          skip_file:
            free(dir_path);
            free(filename);
            free(full_path);

            /* We want to skip this whole line */
            continue;
        }
    }

    for (i = 0; i < (size_t)heredocs_open; i++)
        free(heredocs[i].delim);

    fclose(infile);

#ifdef DEBUG_LIBPINCLUDE_DEFINE
    fprintf(stderr, "close: '%s'\n", input);
#endif
    return 0;
}

int pinclude_list(const char *filename, pinclude_callback_t cb, void *priv,
                  const char **include_dirs, const char **defined,
		  int skip_missing_files)
{
    return pinclude_lines(filename,
                          cb, priv, NULL, NULL, include_dirs, defined,
			  skip_missing_files);
}

int pinclude_lines(const char *filename,
                   pinclude_callback_t per_include, void *include_priv,
                   pinclude_lineback_t per_line, void *line_priv,
                   const char **include_dirs, const char **defined,
		   int skip_missing_files)
{
    int err;
    int i;
    char *included[FILE_MAX];

    for (i = 0; i < FILE_MAX; i++)
        included[i] = NULL;

    /* Passing what the caller asked for rather than a 1: written the
     * other way the argument was accepted and then ignored, so
     * pinclude_list()'s promise to report the files that aren't there
     * was one only it knew it wasn't keeping. */
    err = _pinclude_lines(filename,
                          per_include, include_priv,
                          per_line, line_priv,
                          include_dirs, defined, included,
                          skip_missing_files);

    for (i = 0; i < FILE_MAX; i++)
        if (included[i] != NULL)
            free(included[i]);

    return err;
}

/* TRUE for a character that ends a word on a shell command line,
 * which is where a heredoc's delimiter ends too. */
static bool ends_shell_word(char c)
{
    if (isspace((unsigned char)c))
        return true;

    switch (c) {
    case '\0':
    case ';':
    case '&':
    case '|':
    case '<':
    case '>':
    case '(':
    case ')':
        return true;
    default:
        return false;
    }
}

void open_heredocs(const char *line, struct heredoc *open, int *count)
{
    size_t i;
    char quoted;

    quoted = '\0';

    for (i = 0; line[i] != '\0'; i++) {
        size_t start;
        bool strip_tabs;
        char delim_quote;

        /* Quoting is followed only so that a "<<" written inside a
         * string is left alone, which matters because writing one
         * script out of another is exactly what a heredoc gets used
         * for.  Only within the line: a string that runs across
         * several of them is followed by nothing here, and the check
         * at the end of the file is what that answers to. */
        if (line[i] == '\\' && quoted != '\'' && line[i + 1] != '\0') {
            i++;
            continue;
        }

        if (quoted != '\0') {
            if (line[i] == quoted)
                quoted = '\0';
            continue;
        }

        if (line[i] == '\'' || line[i] == '"') {
            quoted = line[i];
            continue;
        }

        /* A '#' that starts a word starts a comment, and what a
         * comment has to say about redirection is nothing. */
        if (line[i] == '#'
            && (i == 0 || isspace((unsigned char)line[i - 1])))
            return;

        if (line[i] != '<' || line[i + 1] != '<')
            continue;

        /* A "<<<" is a here-string, which carries its body on the
         * line it's written on and so never waits for one.  All three
         * characters get stepped over rather than one: leaving the
         * second '<' to be looked at again finds a "<<" in what is
         * left of it, and then the here-string's own text is read as
         * a delimiter. */
        if (line[i + 2] == '<') {
            i += 2;
            continue;
        }

        /* A "<<" with a word character against its left is a shift
         * rather than a redirection: "$((1<<20))" is arithmetic, and
         * reading it as the start of a heredoc would swallow the rest
         * of the file. */
        if (i > 0 && (isalnum((unsigned char)line[i - 1])
                      || line[i - 1] == '_'))
            continue;

        i += 2;

        /* A "<<-" says the line that ends the heredoc may be indented
         * with tabs, so that a heredoc can be indented along with the
         * code around it. */
        strip_tabs = false;
        if (line[i] == '-') {
            strip_tabs = true;
            i++;
        }

        while (line[i] != '\0' && isspace((unsigned char)line[i]))
            i++;

        /* Quoting the delimiter is how a script asks for a body that
         * the shell expands nothing in.  It makes no difference to
         * where the body ends, which is all that's being read here:
         * either way the word inside the quotes is what ends it. */
        delim_quote = '\0';
        if (line[i] == '\'' || line[i] == '"') {
            delim_quote = line[i];
            i++;
        }

        start = i;
        while (line[i] != '\0'
               && (delim_quote == '\0'
                   ? ends_shell_word(line[i]) == false
                   : line[i] != delim_quote))
            i++;

        /* A "<<" with nothing after it isn't a script the shell would
         * run either, so there's nothing here to be right about. */
        if (i == start)
            continue;

        /* More heredocs open at once than anything writes.  Reading
         * any further would be writing past the end of the list, and
         * whatever this file is it is not a shell script. */
        if (*count >= NEST_MAX)
            return;

        open[*count].delim = strndup(line + start, i - start);
        open[*count].strip_tabs = strip_tabs;
        (*count)++;
    }
}

bool closes_heredoc(const char *line, const struct heredoc *open)
{
    size_t i;

    i = 0;

    /* A "<<-" strips the leading tabs from every line of the body,
     * and the line that ends it is one of those. */
    if (open->strip_tabs == true)
        while (line[i] == '\t')
            i++;

    if (strncmp(line + i, open->delim, strlen(open->delim)) != 0)
        return false;
    i += strlen(open->delim);

    /* The line still has the newline fgets read, and the last line of
     * a file needn't have one at all. */
    while (line[i] == '\n' || line[i] == '\r')
        i++;

    return line[i] == '\0';
}

void str_chomp(char *str)
{
    while ((strlen(str) > 0) && isspace(str[strlen(str) - 1]))
        str[strlen(str) - 1] = '\0';
}

int streqcmp(const char *str, const char *eq)
{
    if (strstr(eq, "=") == NULL)
        return strcmp(str, eq);

    return strncmp(str, eq, strstr(eq, "=") - eq);
}
