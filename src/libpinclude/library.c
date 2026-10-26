
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
#include <sys/stat.h>
#include <unistd.h>

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

    /* Whether it may be indented with any blanks at all, which is
     * what Perl's "<<~" asks for. */
    bool strip_blanks;

    /* The line the "<<" was written on, so that a heredoc which turns
     * out never to end can be pointed at. */
    size_t lineno;

    /* The first line of the body that would have been a directive
     * somewhere else, and where it was.  This is what says whether
     * reading these lines as text changed anything: a body of nothing
     * but text is a body that came out the same either way.  NULL
     * until one turns up. */
    char *swallowed;
    size_t swallowed_lineno;
};

static void str_chomp(char *str);

static int streqcmp(const char *str, const char *eq);

static void open_heredocs(const char *line, size_t lineno,
                          struct heredoc *open, int *count,
                          enum pinclude_language language);

static bool closes_heredoc(const char *line, const struct heredoc *open);

static bool is_directive(const char *line, const char *directive);

static bool reads_as_directive(const char *line);

static char *directive_argument(char *line,
                                const char *directive);

static bool ends_perl_script(const char *line);

static bool includable(const char *path);

static bool is_directory(const char *path);

static void looked_in(const char *dir, const char *filename);

static char *file_identity(const char *path);

static bool already_included(char **included, const char *path);

static void mark_included(char **included, const char *path);

static int _pinclude_lines(const char *input,
                           pinclude_callback_t per_include,
                           void *include_priv, pinclude_lineback_t per_line,
                           void *line_priv, const char **include_dirs,
                           const char **defined, char **included,
			   int skip_missing_files,
                           enum pinclude_language language)
{
    int err;
    FILE *infile;
    /* Whole lines, however long.  This used to be a fixed buffer
     * filled by fgets(), and every piece of a line too long for it was
     * then read as a line of its own: a "-D" name that straddled two
     * pieces wasn't replaced, a "<<EOF" cut into "<<EO" and "F" opened
     * a heredoc that never closed, and an "#include" in the middle of
     * a long string became a directive when it happened to start a
     * piece.  pconfigure's scan reads the same file a whole line at a
     * time, and the two have to agree about what a line is. */
    char *buffer;
    size_t buffer_size;
    ssize_t length;
    size_t i;
    size_t lineno;
    bool found;
    /* Two answers per level of nesting, because an "#else" needs
     * both.  "taken" is what the conditional's own test said, flipped
     * by each "#else"; "state" is whether lines at that level are
     * live, which also needs every enclosing branch to be.  Keeping
     * only the second loses what an "#else" inside a dead branch has
     * to flip, and keeping only the first lets a branch nested in a
     * dead one come back to life on its own test. */
    bool state[NEST_MAX];
    bool taken[NEST_MAX];
    int state_i;
    struct heredoc heredocs[NEST_MAX];
    int heredocs_open;
    bool in_heredoc;
    bool in_data;
    const char *include;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
    fprintf(stderr, "input: '%s'\n", input);
#endif

    infile = fopen(input, "r");

    if (infile == NULL)
        return -1;

    state_i = 0;
    state[state_i] = true;
    taken[state_i] = true;
    lineno = 0;
    heredocs_open = 0;
    in_data = false;
    buffer = NULL;
    buffer_size = 0;

    while ((length = getline(&buffer, &buffer_size, infile)) != -1) {
        lineno++;

        /* Every line from here on is a C string, to be compared,
         * substituted into and written out, and a C string ends at
         * its first NUL.  A NUL in the middle of a line -- an archive
         * appended to a self-extracting script is the usual way to
         * get one -- used to cut the line short there, so the program
         * came out carrying something other than what was written and
         * nothing said so.  Carrying the bytes through would mean
         * every line having a length rather than an end, and a binary
         * payload still isn't safe from being read as script: one of
         * its lines that happens to start "#include" is expanded.  So
         * it is refused, and pointed at.
         *
         * Only when expanding: a list of includes loses nothing to a
         * line cut short, since no directive starts after a NUL. */
        if (per_line != NULL && strlen(buffer) != (size_t)length) {
            fprintf(stderr, "%s:%zu: a NUL byte, which can't be carried"
                    " through into the compiled program\n",
                    input, lineno);
            fprintf(stderr, "  each line is read as text, and text ends at"
                    " its first NUL, so the rest of the line would be"
                    " lost\n");
            fprintf(stderr, "  keep binary data in a file of its own for"
                    " the script to read, or write it in encoded, with"
                    " base64 for instance\n");

            free(buffer);
            fclose(infile);

            return -1;
        }

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
            if (in_heredoc == true || in_data == true
                || strncmp(buffer, "#include", 8) != 0) {
                if ((err = per_line(buffer, line_priv)) != 0) {
                    free(buffer);
                    fclose(infile);

                    return err;
                }

                /* The last line of a file needn't end in a newline,
                 * but whatever comes after this file in the output --
                 * the next line of the file that included it -- has
                 * to start a line of its own rather than being glued
                 * onto this one, so the end of the file ends the line.
                 * getline() hands back whole lines, so the only one
                 * that can be missing its newline is the last. */
                if (buffer[length - 1] != '\n') {
                    if ((err = per_line("\n", line_priv)) != 0) {
                        free(buffer);
                        fclose(infile);

                        return err;
                    }
                }
            }
        }

        /* Below a Perl script's "__DATA__" or "__END__" line is data
         * the script reads, or nothing at all, and is never script --
         * a heredoc's body that runs to the end of the file, as far as
         * anything here is concerned, and one that is supposed to.  A
         * C template kept down there brings its "#include" lines along
         * just as one in a heredoc does.
         *
         * Only to the end of this file.  An included file is pasted in
         * whole, so its "__END__" ends the script it is pasted into as
         * well; but saying so here would quietly stop expanding the
         * includes after it, which is a worse way to find that out
         * than perl not running what follows. */
        if (in_data == true)
            continue;

        if (in_heredoc == true) {
            /* What this heredoc has to answer for if it turns out
             * never to end.  Only the first one is kept: a heredoc
             * that ate the whole rest of the file has as many of
             * these as the file had left, and naming one of them is
             * what points at where things went wrong. */
            if (heredocs[0].swallowed == NULL
                && reads_as_directive(buffer) == true) {
                heredocs[0].swallowed = strdup(buffer);
                str_chomp(heredocs[0].swallowed);
                heredocs[0].swallowed_lineno = lineno;
            }

            if (closes_heredoc(buffer, &heredocs[0]) == true) {
                int h;

                free(heredocs[0].delim);
                free(heredocs[0].swallowed);
                for (h = 1; h < heredocs_open; h++)
                    heredocs[h - 1] = heredocs[h];
                heredocs_open--;
            }

            continue;
        }

        /* Asked whatever the #ifdef state is, since that only ever
         * decides which includes are pasted in: every other line goes
         * out regardless, and perl sees this one wherever it is. */
        if (language == PINCLUDE_PERL && ends_perl_script(buffer) == true) {
            in_data = true;
            continue;
        }

        /* Here's where we handle the #if{,n}def preprocessor
         * directives. */
        if (strncmp(buffer, "#ifdef ", strlen("#ifdef ")) == 0 ||
            strncmp(buffer, "#ifdef\t", strlen("#ifdef\t")) == 0) {
            char *define;
            bool matched;

            /* The name is whatever comes after all the blanks, not
             * after the first one: the scan skips every one of them,
             * so "#ifdef  NAME" asked it about NAME while this
             * compared " NAME" against the -D's and never matched --
             * the two then disagreed about which includes the script
             * was made of. */
            define = directive_argument(buffer, "#ifdef");
            str_chomp(define);

            /* A define can carry a value, "NAME=value", and it
             * defines NAME all the same -- which is how "#ifndef"
             * below already read it.  Comparing the whole of it here
             * made a valued define leave "#ifdef NAME" and
             * "#ifndef NAME" both false. */
            matched = false;
            for (i = 0; defined[i] != NULL; i++)
                if (streqcmp(define, defined[i]) == 0)
                    matched = true;

            state_i++;
            taken[state_i] = matched;
            state[state_i] = state[state_i - 1] && taken[state_i];

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "ifdef: '%s' (%d -> %d)\n",
                    define, state_i, state[state_i]);
#endif
        }

        if (strncmp(buffer, "#ifndef ", strlen("#ifndef ")) == 0 ||
            strncmp(buffer, "#ifndef\t", strlen("#ifndef\t")) == 0) {
            char *define;
            bool matched;

            define = directive_argument(buffer, "#ifndef");
            str_chomp(define);

            matched = false;
            for (i = 0; defined[i] != NULL; i++)
                if (streqcmp(define, defined[i]) == 0)
                    matched = true;

            state_i++;
            taken[state_i] = !matched;
            state[state_i] = state[state_i - 1] && taken[state_i];

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "ifndef: '%s' (%d -> %d)\n",
                    define, state_i, state[state_i]);
#endif
        }

        /* Unlike the "#ifdef"s above, neither of these has anything
         * after it to need a space in front of, so all that ends the
         * keyword is a word ending.  Matching the first few letters
         * alone took a comment such as "#elsewhere ..." for an
         * "#else" -- flipping a conditional that wasn't there and
         * silently dropping every include after it -- and disagreed
         * with the dependency scan, which wants the word to end. */
        if (is_directive(buffer, "#else") == true) {
            /* An "#else" works out its branch from the one around it,
             * and at the top of the file there isn't one: there is
             * nothing for it to be the other half of. */
            if (state_i == 0) {
                fprintf(stderr, "%s:%zu: #else without an #if before it\n",
                        input, lineno);
                abort();
            }

            taken[state_i] = !taken[state_i];
            state[state_i] = state[state_i - 1] && taken[state_i];

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "else: (%d -> %d)\n", state_i, state[state_i]);
#endif
        }

        /* An "#if" in a file being expanded is refused rather than
         * read.  This used to take every one of them as true, which
         * kept the "#endif" count straight and nothing else: "#if 0",
         * the obvious way to switch an include off, pasted the
         * include in anyway.  pconfigure's scan of the same script
         * evaluates the expression, so the two disagreed about which
         * files the script was made of, and make was never told about
         * the one that got pasted in.
         *
         * Evaluating it here instead would mean two expression
         * readers that have to agree on everything an "#if" can say,
         * for a script whose only names are the "-D"s it was given --
         * which "#ifdef" and "#ifndef" already ask about.  Refusing
         * it in both places is the one answer they can't drift apart
         * on.  It also catches a comment that happens to start with
         * the word, "#if you want...", which is better told about
         * than quietly opening a conditional nothing closes.
         *
         * It is refused wherever it turns up, taken branch or not, so
         * that whether a script is accepted doesn't depend on which
         * "-D"s it was built with this time. */
        if (is_directive(buffer, "#if") == true && per_line != NULL) {
            char *line;

            line = strdup(buffer);
            str_chomp(line);

            fprintf(stderr, "%s:%zu: '%s' can't be used in a script\n",
                    input, lineno, line);
            fprintf(stderr, "  only '#ifdef NAME' and '#ifndef NAME' decide"
                    " what is pasted in, and an '#if' expression is never"
                    " worked out\n");
            fprintf(stderr, "  write '#ifdef NAME' with the name given as a"
                    " '-D' in COMPILEOPTS, or '# if' with a space if this"
                    " is a comment\n");

            free(line);
            free(buffer);
            fclose(infile);

            return -1;
        }

        /* Only listing gets this far with an "#if", and listing can
         * afford to take every one of them as true: a file listed
         * that turns out not to be read costs a rebuild, where one
         * left off is an edit that never causes one.  pbashc never
         * lists, so nothing it builds depends on this guess. */
        if (is_directive(buffer, "#if") == true) {
            state_i++;
            taken[state_i] = true;
            state[state_i] = state[state_i - 1];
        }

        if (is_directive(buffer, "#endif") == true) {
            if (state_i == 0)
                abort();

            state_i--;

#ifdef DEBUG_LIBPINCLUDE_DEFINE
            fprintf(stderr, "endif: (%d -> %d)\n", state_i, state[state_i]);
#endif
        }

        /* What this line opens, which is what the lines after it are
         * the body of.  Asked whatever the #ifdef state is: a branch
         * that isn't taken still has its lines read, a heredoc's body
         * among them, and only its includes are left out.  Opening
         * heredocs only in taken branches read the body of one that
         * wasn't as directives, so an "#if 0" written into a C file
         * was refused and a lone "#endif" closed the "#ifdef" around
         * the heredoc -- but only when the name wasn't defined, while
         * pconfigure's scan of the same script opens the heredoc
         * either way and had already said the script was fine. */
        open_heredocs(buffer, lineno, heredocs, &heredocs_open, language);

        /* If we're #ifdef'd out then skip the line. */
        if (state[state_i] == false)
            continue;

        /* Finally attempt to recursively enumerate the #include
         * files.
         *
         * Any number of blanks may come between the keyword and the
         * name, or none at all, since a quote ends the keyword as
         * well as a space does.  That is how the scan reads an
         * include, and every line starting "#include" was already
         * kept out of the output above: matching only the spelling
         * with exactly one space dropped '#include  "x"',
         * '#include<TAB>"x"' and '#include"x"' without pasting
         * anything in their place, so the script came out with a
         * file missing that make had been told it was made of.
         *
         * Both "" and <> are treated the same here, unlike in C: what
         * this expands is scripts, and a script's includes are all
         * files belonging to whoever wrote it.  Several of the tests
         * in this tree write their harness the angled way.  Anything
         * else after the keyword is a computed include, which the
         * scan passes over as well, and pastes nothing. */
        include = directive_argument(buffer, "#include");
        if (include != NULL && (include[0] == '"' || include[0] == '<')) {
            size_t slash_max;

            char *full_path;
            char *dir_path;
            char *filename;
            bool absolute;

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
            filename = strdup(include + 1);
            {
                char *close = strchr(filename, include[0] == '<' ? '>' : '"');
                if (close != NULL)
                    *close = '\0';
                else
                    str_chomp(filename);
            }

            /* An absolute name is the one file it names: it is
             * looked for there and nowhere else, as the scan in
             * library.c++ does and the compiler does for a header.
             * Glued onto the script's own directory it named nothing,
             * so a helper written by its full path was refused as a
             * file that couldn't be found. */
            absolute = filename[0] == '/';

            if (absolute) {
                full_path = strdup(filename);
            } else if (strcmp(dir_path, ".") != 0) {
                if (asprintf(&full_path, "%s/%s", dir_path, filename) < 0)
                    abort();
            } else {
                if (asprintf(&full_path, "%s", filename) < 0)
                    abort();
            }

            if (already_included(included, full_path) == true)
                goto skip_file;

            found = false;

            if (includable(full_path) == true) {
                mark_included(included, full_path);

#ifdef DEBUG_LIBPINCLUDE_INCLUDE
                fprintf(stderr, "inc: '%s'\n", full_path);
#endif

                if (per_include != NULL) {
                    if ((err = per_include(full_path, include_priv)) != 0) {
                        free(dir_path);
                        free(filename);
                        free(full_path);
                        free(buffer);
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
                        free(buffer);
                        fclose(infile);

                        return err;
                    }
                }
	    }

            /* Check each additional include directory */
            for (i = 0; !absolute && include_dirs[i] != NULL; i++) {
                free(full_path);
                if (asprintf(&full_path, "%s/%s", include_dirs[i], filename) <
                    0)
                    abort();

                if (already_included(included, full_path) == true)
                    goto skip_file;

                if (includable(full_path) == true) {
                    mark_included(included, full_path);

                    if (per_include != NULL) {
                        if ((err = per_include(full_path, include_priv)) != 0) {
                            free(dir_path);
                            free(filename);
                            free(full_path);
                            free(buffer);
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

                /* No directory was searched for an absolute name, so
                 * listing them would only send whoever reads this
                 * looking in the wrong places. */
                if (absolute) {
                    if (is_directory(filename) == true)
                        fprintf(stderr, "  '%s' is a directory rather"
                                " than a file\n", filename);
                    fprintf(stderr,
                            "  an absolute path is looked for there and"
                            " nowhere else, so check the spelling\n");

                    free(dir_path);
                    free(filename);
                    free(full_path);
                    free(buffer);
                    fclose(infile);

                    return -1;
                }

                looked_in(dir_path, filename);
                for (i = 0; include_dirs[i] != NULL; i++) {
                    /* The file's own directory is often on the list
                     * as well, and saying it twice reads like two
                     * different places were tried. */
                    if (strcmp(include_dirs[i], dir_path) == 0)
                        continue;

                    looked_in(include_dirs[i], filename);
                }
                fprintf(stderr,
                        "  check the spelling, or add a '-I' for the"
                        " directory it's in\n");

                free(dir_path);
                free(filename);
                free(full_path);
                free(buffer);
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
                                       skip_missing_files,
                                       language)) != 0) {
                free(dir_path);
                free(filename);
                free(full_path);
                free(buffer);
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

    /* A heredoc that nothing ever ended has taken the rest of the
     * file for its body, and every directive down there has quietly
     * stopped being one.  That is exactly the failure this whole
     * business exists to avoid, arrived at from the other side, so it
     * has to stop rather than hand back a file with the includes
     * missing from it.
     *
     * A body of nothing but text is left alone.  Reading it as text
     * is what it was going to get either way, so there is nothing
     * here that came out differently and nothing to complain about --
     * which matters, because the "<<" that opens a heredoc is not
     * always distinguishable from the one that shifts. */
    if (heredocs_open > 0 && heredocs[0].swallowed != NULL) {
        fprintf(stderr, "%s:%zu: '%s' was read as the body of a heredoc\n",
                input, heredocs[0].swallowed_lineno, heredocs[0].swallowed);
        fprintf(stderr, "  the '<<' on line %zu has no '%s' after it, so"
                " everything below it is that heredoc's body\n",
                heredocs[0].lineno, heredocs[0].delim);
        fprintf(stderr, "  end the heredoc, or write the '<<' some other"
                " way if it was never the start of one\n");

        for (i = 0; i < (size_t)heredocs_open; i++) {
            free(heredocs[i].delim);
            free(heredocs[i].swallowed);
        }

        free(buffer);
        fclose(infile);

        return -1;
    }

    for (i = 0; i < (size_t)heredocs_open; i++) {
        free(heredocs[i].delim);
        free(heredocs[i].swallowed);
    }

    free(buffer);
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
    return pinclude_lines_language(filename,
                                   per_include, include_priv,
                                   per_line, line_priv,
                                   include_dirs, defined,
                                   skip_missing_files,
                                   PINCLUDE_SHELL);
}

int pinclude_lines_language(const char *filename,
                            pinclude_callback_t per_include,
                            void *include_priv,
                            pinclude_lineback_t per_line, void *line_priv,
                            const char **include_dirs, const char **defined,
                            int skip_missing_files,
                            enum pinclude_language language)
{
    int err;
    int i;
    char *included[FILE_MAX];

    for (i = 0; i < FILE_MAX; i++)
        included[i] = NULL;

    /* The file being expanded is the first thing in the output, so it
     * is the first thing on the list of what has been pasted.  Left
     * off, a helper that includes the script it was included from
     * pastes the whole script in again inside itself, and every line
     * of the program runs twice. */
    mark_included(included, filename);

    /* Passing what the caller asked for rather than a 1: written the
     * other way the argument was accepted and then ignored, so
     * pinclude_list()'s promise to report the files that aren't there
     * was one only it knew it wasn't keeping. */
    err = _pinclude_lines(filename,
                          per_include, include_priv,
                          per_line, line_priv,
                          include_dirs, defined, included,
                          skip_missing_files,
                          language);

    for (i = 0; i < FILE_MAX; i++)
        if (included[i] != NULL)
            free(included[i]);

    return err;
}

/* What says two paths name the same file, for the list of what has
 * already been pasted.  The path as it was spelled doesn't: an
 * include is spelled from the directory of the file it's in, so one
 * common file is "src/common.bash" from one place and
 * "src/lib/../common.bash" from another, and "./helper.bash" is
 * "helper.bash".  Each of those used to be pasted once per spelling.
 *
 * realpath() rather than taking the dots out by hand, the way the
 * scan in library.c++ does: this is only ever asked about a file that
 * is there, and resolving it properly means a ".." after a symlinked
 * directory goes where the kernel would send it rather than to
 * whichever file happens to sit beside the link.  A path realpath()
 * can't resolve is kept as written, which is no worse than before;
 * opening it is about to fail and say so anyway. */
static char *file_identity(const char *path)
{
    char *resolved;

    resolved = realpath(path, NULL);
    if (resolved != NULL)
        return resolved;

    resolved = strdup(path);
    if (resolved == NULL)
        abort();

    return resolved;
}

static bool already_included(char **included, const char *path)
{
    char *identity;
    bool found;
    size_t i;

    identity = file_identity(path);

    found = false;
    for (i = 0; i < FILE_MAX; i++)
        if (included[i] != NULL && strcmp(identity, included[i]) == 0)
            found = true;

    free(identity);

    return found;
}

static void mark_included(char **included, const char *path)
{
    size_t i;

    for (i = 0; i < FILE_MAX; i++) {
        if (included[i] != NULL)
            continue;

        included[i] = file_identity(path);
        return;
    }
}

/* Whether an "#include" may be satisfied by PATH.  Being readable is
 * not enough: access() says yes to a directory, fopen() opens one,
 * and getline() then reads nothing from it, so a directory that shared
 * an include's name used to be pasted in as an empty file -- a script
 * with a piece silently missing and an exit status of zero.  A
 * directory is never the file an include means, so it is passed over
 * just as a name that isn't there is, and the search carries on to
 * the next place it might be. */
static bool includable(const char *path)
{
    if (access(path, R_OK) != 0)
        return false;

    return is_directory(path) == false;
}

static bool is_directory(const char *path)
{
    struct stat st;

    if (stat(path, &st) != 0)
        return false;

    return S_ISDIR(st.st_mode);
}

/* One line of the list of places an include that couldn't be found
 * was looked for.  A directory by the right name is called out: from
 * where the person who wrote the include is standing the name plainly
 * exists, so "can't find" alone reads as though the search were
 * broken rather than as the include naming the wrong thing. */
static void looked_in(const char *dir, const char *filename)
{
    char *path;

    if (asprintf(&path, "%s/%s", dir, filename) < 0)
        abort();

    if (is_directory(path) == true)
        fprintf(stderr, "  looked in '%s', where '%s' is a directory"
                " rather than a file\n", dir, path);
    else
        fprintf(stderr, "  looked in '%s'\n", dir);

    free(path);
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

/* Decodes the backslash escape inside a $'...' that starts at s, just
 * past the backslash, into out, the way bash does: \n, \t and the
 * other single letters, up to three octal digits, \x with up to two
 * hex digits, \u and \U as UTF-8, and \c as a control character.  The
 * number of characters of s it used goes in *used, and what it
 * returns is the number of bytes written to out, which has room for
 * at least four.  Anything bash doesn't know as an escape is kept,
 * backslash and all, as bash keeps it. */
static size_t decode_ansi_c_escape(const char *s, size_t *used, char *out)
{
    unsigned long value;
    size_t digits, max_digits;
    int base;

    *used = 1;
    switch (s[0]) {
    case 'a': out[0] = '\a'; return 1;
    case 'b': out[0] = '\b'; return 1;
    case 'e':
    case 'E': out[0] = '\033'; return 1;
    case 'f': out[0] = '\f'; return 1;
    case 'n': out[0] = '\n'; return 1;
    case 'r': out[0] = '\r'; return 1;
    case 't': out[0] = '\t'; return 1;
    case 'v': out[0] = '\v'; return 1;
    case '\\':
    case '\'':
    case '"':
    case '?': out[0] = s[0]; return 1;
    case 'c':
        if (s[1] == '\0') {
            out[0] = '\\';
            out[1] = 'c';
            return 2;
        }
        *used = 2;
        out[0] = (s[1] == '?')
            ? 0x7f : (toupper((unsigned char)s[1]) & 0x1f);
        return 1;
    case 'x': base = 16; max_digits = 2; break;
    case 'u': base = 16; max_digits = 4; break;
    case 'U': base = 16; max_digits = 8; break;
    default:
        if (s[0] >= '0' && s[0] <= '7') {
            base = 8;
            max_digits = 3;
            break;
        }
        out[0] = '\\';
        out[1] = s[0];
        return 2;
    }

    /* An octal escape's first digit is the character right after the
     * backslash; the others name the base and then give digits. */
    digits = 0;
    value = 0;
    *used = (base == 8) ? 0 : 1;
    while (digits < max_digits) {
        char c = s[*used];
        int digit;

        if (base == 8 && c >= '0' && c <= '7')
            digit = c - '0';
        else if (base == 16 && isxdigit((unsigned char)c))
            digit = isdigit((unsigned char)c)
                ? c - '0' : tolower((unsigned char)c) - 'a' + 10;
        else
            break;

        value = value * base + digit;
        digits++;
        (*used)++;
    }

    if (digits == 0) {
        out[0] = '\\';
        out[1] = s[0];
        return 2;
    }

    if (s[0] != 'u' && s[0] != 'U') {
        out[0] = (char)value;
        return 1;
    }

    if (value < 0x80) {
        out[0] = (char)value;
        return 1;
    }
    if (value < 0x800) {
        out[0] = (char)(0xc0 | (value >> 6));
        out[1] = (char)(0x80 | (value & 0x3f));
        return 2;
    }
    if (value < 0x10000) {
        out[0] = (char)(0xe0 | (value >> 12));
        out[1] = (char)(0x80 | ((value >> 6) & 0x3f));
        out[2] = (char)(0x80 | (value & 0x3f));
        return 3;
    }
    out[0] = (char)(0xf0 | ((value >> 18) & 0x07));
    out[1] = (char)(0x80 | ((value >> 12) & 0x3f));
    out[2] = (char)(0x80 | ((value >> 6) & 0x3f));
    out[3] = (char)(0x80 | (value & 0x3f));
    return 4;
}

/* Reads the word a "<<" was given, starting at line[*i], and returns
 * it the way the shell compares it against the body's lines: with its
 * quoting taken out.  That quoting can be anywhere in the word and in
 * any of the shell's spellings, so <<'END', <<\END, <<E\ND, <<E"N"D
 * and <<$'END' are all ended by a line saying END; taking only a
 * quote at the front of the word leaves the others waiting for a
 * line no script writes, and the body then swallows the rest of the
 * file.  *i is left on the character that ended the word.  A quote
 * left open runs to the end of the line, which is as far as anything
 * here reads. */
static char *read_heredoc_delim(const char *line, size_t *i)
{
    char *out;
    size_t n;

    /* Taking quoting out never makes a word longer: even a \u or \U
     * escape is spelled in more characters than its UTF-8 takes. */
    out = (char *)malloc(strlen(line + *i) + 1);
    if (out == NULL) {
        perror("malloc()");
        abort();
    }
    n = 0;

    while (ends_shell_word(line[*i]) == false) {
        if (line[*i] == '\\' && line[*i + 1] != '\0') {
            out[n++] = line[*i + 1];
            *i += 2;
            continue;
        }

        if (line[*i] == '\'') {
            (*i)++;
            while (line[*i] != '\0' && line[*i] != '\'')
                out[n++] = line[(*i)++];
            if (line[*i] != '\0')
                (*i)++;
            continue;
        }

        /* A $'...' is single quoting that also reads backslash
         * escapes.  One that comes out as a NUL ends the string as
         * far as bash is concerned, so the rest of the quote adds
         * nothing to the word. */
        if (line[*i] == '$' && line[*i + 1] == '\'') {
            bool ended = false;

            *i += 2;
            while (line[*i] != '\0' && line[*i] != '\'') {
                char decoded[4];
                size_t used, length, k;

                if (line[*i] != '\\' || line[*i + 1] == '\0') {
                    if (ended == false)
                        out[n++] = line[*i];
                    (*i)++;
                    continue;
                }

                length = decode_ansi_c_escape(line + *i + 1, &used,
                                              decoded);
                for (k = 0; k < length && ended == false; k++) {
                    if (decoded[k] == '\0')
                        ended = true;
                    else
                        out[n++] = decoded[k];
                }
                *i += 1 + used;
            }
            if (line[*i] != '\0')
                (*i)++;
            continue;
        }

        /* A $"..." is double quoting that asks for the string to be
         * translated, which is nothing to do with where a body ends;
         * the '$' just goes. */
        if (line[*i] == '$' && line[*i + 1] == '"')
            (*i)++;

        /* Inside double quotes a backslash only quotes the characters
         * that would mean something there, and is otherwise just a
         * backslash. */
        if (line[*i] == '"') {
            (*i)++;
            while (line[*i] != '\0' && line[*i] != '"') {
                if (line[*i] == '\\' && line[*i + 1] != '\0'
                    && strchr("$`\"\\", line[*i + 1]) != NULL)
                    (*i)++;
                out[n++] = line[(*i)++];
            }
            if (line[*i] != '\0')
                (*i)++;
            continue;
        }

        out[n++] = line[(*i)++];
    }

    out[n] = '\0';
    return out;
}

/* Whether what follows a Perl "<<" (and any "~") is a terminator,
 * which is a quoted string with or without blanks before it or a word
 * written right against the "<<".  A backslash in that place is the
 * old spelling of single quotes, and still a heredoc. */
static bool perl_heredoc_follows(const char *rest)
{
    size_t i;

    if (isalnum((unsigned char)rest[0]) || rest[0] == '_'
        || rest[0] == '\\')
        return true;

    i = 0;
    while (rest[i] != '\0' && isspace((unsigned char)rest[i]))
        i++;

    return rest[i] == '"' || rest[i] == '\'' || rest[i] == '`';
}

void open_heredocs(const char *line, size_t lineno,
                   struct heredoc *open, int *count,
                   enum pinclude_language language)
{
    size_t i;
    size_t delim_end;
    char quoted;

    quoted = '\0';

    /* Where the last delimiter read on this line ended, which no word
     * can at the start of the line. */
    delim_end = 0;

    for (i = 0; line[i] != '\0'; i++) {
        size_t start;
        bool strip_tabs;
        bool strip_blanks;
        char *delim;
        bool empty;

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
         * of the file.  The exception is a "<<" written right against
         * the delimiter of the one before it, as in "<<A<<B": there
         * is no arithmetic in a delimiter, and that '<' is what ended
         * it. */
        if (i > 0 && i != delim_end
            && (isalnum((unsigned char)line[i - 1])
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

        /* Perl's "<<~" is the same idea with any blanks rather than
         * tabs alone.  It is Perl's only: to the shell a "~" is just
         * the first letter of the delimiter, and a shell script that
         * ends its heredoc at "~EOT" has to keep doing so. */
        strip_blanks = false;
        if (language == PINCLUDE_PERL && strip_tabs == false
            && line[i] == '~') {
            strip_blanks = true;
            i++;
        }

        /* Perl reads a terminator in fewer places than the shell does.
         * A quoted one may have blanks before it, but an unquoted one
         * has to be written right against the "<<", and has to be a
         * word: "1 << 4" is a shift, and so is "$x <<= 2" with its
         * "=".  Reading either with the shell's rule opens a heredoc
         * that no line ends, and every include after it is lost.  The
         * character after the "<<" is looked at again, as the one
         * after a delimiter is. */
        if (language == PINCLUDE_PERL
            && perl_heredoc_follows(line + i) == false) {
            i--;
            continue;
        }

        while (line[i] != '\0' && isspace((unsigned char)line[i]))
            i++;

        /* Quoting the delimiter is how a script asks for a body that
         * the shell expands nothing in.  It makes no difference to
         * where the body ends, which is all that's being read here:
         * what ends it is the word with its quoting taken out. */
        start = i;
        delim = read_heredoc_delim(line, &i);

        /* The character that ended the word is looked at again rather
         * than stepped over, since it can be the '<' of another
         * redirection written right against this one, as in
         * "<<'A'<<'B'", or the '\0' of a last line with no newline. */
        empty = (i == start);
        delim_end = i;
        i--;

        /* A "<<" with nothing after it isn't a script the shell would
         * run either, so there's nothing here to be right about.  A
         * "<<''" is different: bash takes that as a heredoc an empty
         * line ends, and so does this. */
        if (empty == true) {
            free(delim);
            continue;
        }

        /* More heredocs open at once than anything writes.  Reading
         * any further would be writing past the end of the list, and
         * whatever this file is it is not a shell script. */
        if (*count >= NEST_MAX) {
            free(delim);
            return;
        }

        open[*count].delim = delim;
        open[*count].strip_tabs = strip_tabs;
        open[*count].strip_blanks = strip_blanks;
        open[*count].lineno = lineno;
        open[*count].swallowed = NULL;
        open[*count].swallowed_lineno = 0;
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

    /* A "<<~" ends at its delimiter however that line is indented. */
    if (open->strip_blanks == true)
        while (line[i] == ' ' || line[i] == '\t')
            i++;

    if (strncmp(line + i, open->delim, strlen(open->delim)) != 0)
        return false;
    i += strlen(open->delim);

    /* The line still has the newline getline read, and the last line of
     * a file needn't have one at all. */
    while (line[i] == '\n' || line[i] == '\r')
        i++;

    return line[i] == '\0';
}

bool is_directive(const char *line, const char *directive)
{
    size_t length;
    char after;

    length = strlen(directive);
    if (strncmp(line, directive, length) != 0)
        return false;

    /* A directive's name ends where an identifier ends, so that
     * "#included" is a word which starts with one rather than one of
     * them, and "#ifdef" is not an "#if". */
    after = line[length];
    if (isalnum((unsigned char)after) || after == '_')
        return false;

    return true;
}

/* Where DIRECTIVE's argument starts in LINE, past every blank between
 * the two, or NULL when LINE isn't that directive at all.  The scan
 * skips the same blanks before it reads the name, and the name has to
 * come out the same in both places for the two to agree about which
 * files a script reads. */
char *directive_argument(char *line, const char *directive)
{
    if (is_directive(line, directive) == false)
        return NULL;

    line += strlen(directive);
    while (*line == ' ' || *line == '\t')
        line++;

    return line;
}

bool reads_as_directive(const char *line)
{
    static const char *const directives[] = {
        "#include", "#ifdef", "#ifndef", "#if", "#else", "#endif", NULL
    };
    size_t i;

    for (i = 0; directives[i] != NULL; i++)
        if (is_directive(line, directives[i]) == true)
            return true;

    return false;
}

/* TRUE for the line that ends a Perl script, after which perl reads
 * nothing more of it as code.  The marker is a token rather than a
 * line, so it may be indented, but it is the whole of an identifier:
 * "__END__X" is a name like any other. */
bool ends_perl_script(const char *line)
{
    static const char *const markers[] = { "__END__", "__DATA__", NULL };
    size_t i;
    size_t m;

    i = 0;
    while (line[i] == ' ' || line[i] == '\t')
        i++;

    for (m = 0; markers[m] != NULL; m++) {
        size_t length;
        char after;

        length = strlen(markers[m]);
        if (strncmp(line + i, markers[m], length) != 0)
            continue;

        after = line[i + length];
        if (isalnum((unsigned char)after) || after == '_')
            continue;

        return true;
    }

    return false;
}

void str_chomp(char *str)
{
    while ((strlen(str) > 0) && isspace(str[strlen(str) - 1]))
        str[strlen(str) - 1] = '\0';
}

/* Compares a name against a define that may have a value on it.  Only
 * the part before the "=" is the name, and all of the name has to
 * match: comparing just as many characters as the define's name has
 * would say "FANCYX" was defined by "FANCY=yes". */
int streqcmp(const char *str, const char *eq)
{
    size_t len;

    if (strstr(eq, "=") == NULL)
        return strcmp(str, eq);

    len = strstr(eq, "=") - eq;
    if (strlen(str) != len)
        return 1;
    return strncmp(str, eq, len);
}
