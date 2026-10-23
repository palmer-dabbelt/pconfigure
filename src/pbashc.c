
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

#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <pinclude.h>

#ifndef SHEBANG_PREFIX
#define SHEBANG_PREFIX ""
#endif

#if defined(LANG_PERL)

#if defined(__gnu_linux__) || defined(__APPLE__)
#define SHEBANG "#!" SHEBANG_PREFIX "/usr/bin/perl\n"
#else
#error "Where does Perl live on this system?"
#endif

#elif defined(LANG_BASH)

#if defined(__gnu_linux__) || defined(__APPLE__)
#define SHEBANG "#!" SHEBANG_PREFIX "/bin/bash\n"
#else
#error "Where does Bash live on this system?"
#endif

#else
#error "No language defined"
#endif

/* The output file is a global file. */
static FILE *outfile;

/* Writes a line out to the output file. */
static int write_line(const char *line, void *unused);

/* Pretty much does sed, but with a bit of massaging and only
 * string-to-string. */
static char *replace(const char *line, const char *pair);

int main(int argc, char **argv)
{
    char *input, *output;
    char **dirs;
    char **defs;
    int dirs_count;
    int defs_count;
    int i;
    char *tmpout;
    int tmpout_size;
    char *chmod;
    int chmod_size;
    int ret;
    struct stat input_stat;

    input = NULL;
    output = NULL;

    /* Every flag that takes something takes at most one word, so
     * there can't be more of either than there are words. */
    dirs = malloc(sizeof(*dirs) * argc);
    defs = malloc(sizeof(*defs) * argc);
    dirs_count = 0;
    defs_count = 0;

    /* "-I" and "-D" are taken both glued to what they carry and as a
     * word of their own, because that is how the C languages take
     * them and a COMPILEOPTS is written once for whichever language
     * reads it.  Only the glued spelling used to be understood here:
     * "-I inc" came out as an empty search directory and an "inc"
     * that, being a bare word, quietly became the input.  A directory
     * opens and reads as nothing, so the result was a shebang and an
     * empty script, and a pbashc that exited zero.
     *
     * "-i" is how pconfigure names the input.  It used to work only
     * by accident -- "-i" was a bare word, so it was the input until
     * the real one came along and replaced it -- and now that a
     * second input is refused rather than taken it has to be known
     * for what it is. */
    for (i = 1; i < argc; i++) {
        const char *flag;
        const char *value;

        flag = NULL;
        value = NULL;
        if (strcmp(argv[i], "-o") == 0 || strcmp(argv[i], "-i") == 0
            || strcmp(argv[i], "-I") == 0 || strcmp(argv[i], "-D") == 0) {
            flag = argv[i];
            if (i + 1 >= argc) {
                fprintf(stderr, "'%s' needs something after it\n", flag);
                exit(1);
            }
            value = argv[++i];
        } else if (strncmp(argv[i], "-I", 2) == 0
                   || strncmp(argv[i], "-D", 2) == 0) {
            flag = argv[i];
            value = argv[i] + 2;
        }

        if (flag == NULL || strcmp(flag, "-i") == 0) {
            /* There is one input and it is the whole program, so a
             * second one is a mistake rather than a replacement: it
             * is almost always a flag pbashc doesn't know, or the
             * second half of one it read as a whole, and taking the
             * last of them threw the real input away without a word
             * about it. */
            const char *word = (flag == NULL) ? argv[i] : value;
            if (input != NULL) {
                fprintf(stderr,
                        "two input files, '%s' and '%s': pbashc compiles "
                        "one file into one program\n"
                        "  a search directory is '-I dir' or '-Idir', and "
                        "a definition '-D name' or '-Dname'\n",
                        input, word);
                exit(1);
            }
            input = (char *)word;
        } else if (strcmp(flag, "-o") == 0) {
            output = (char *)value;
        } else if (strncmp(flag, "-I", 2) == 0) {
            dirs[dirs_count++] = (char *)value;
        } else {
            defs[defs_count++] = (char *)value;
        }
    }
    dirs[dirs_count] = NULL;
    defs[defs_count] = NULL;

    if ((input == NULL) || (output == NULL)) {
        fprintf(stderr, "needs 2 arguments\ninput '%s'\noutput '%s'\n",
                input, output);
        exit(1);
    }

    /* fopen() is quite happy to open a directory, and reading one
     * gives back nothing at all, so a directory handed over as the
     * input compiled to an empty script and succeeded.  That is
     * never what anybody meant. */
    if (stat(input, &input_stat) == 0 && S_ISDIR(input_stat.st_mode)) {
        fprintf(stderr,
                "input '%s' is a directory rather than a file to compile\n"
                "  if it is meant to be searched for includes, write "
                "'-I %s'\n",
                input, input);
        exit(1);
    }

    /* Written beside where it goes and renamed over it at the end,
     * rather than through whatever is already there.
     *
     * The output of a compile is a program, and a program is a thing
     * something may well be running: opening it and writing through
     * it doesn't replace it, it changes the file that is already
     * open.  On macOS that is fatal rather than merely rude, since
     * the kernel checks a program's code signature once and remembers
     * the answer against that file -- so a file whose contents
     * changed while the answer stayed behind is one the next exec of
     * kills with SIGKILL and nothing printed.
     *
     * It is also what keeps a compile that fails from leaving
     * anything behind.  The output is written as it goes, so at the
     * point one gives up there is a shebang and however far it got on
     * disk; that used to be dealt with by deleting the output, which
     * threw away the last one that worked along with it. */
    tmpout_size = strlen(output) + strlen(".tmp") + 1;
    tmpout = malloc(tmpout_size);
    snprintf(tmpout, tmpout_size, "%s.tmp", output);

    outfile = fopen(tmpout, "w");
    if (outfile == NULL) {
        fprintf(stderr, "unable to write '%s'\n", tmpout);
        exit(1);
    }

    fprintf(outfile, SHEBANG "\n");

    if (pinclude_lines(input, NULL, NULL, &write_line, defs, (const char **)dirs, (const char **)defs, 1) != 0) {
        fprintf(stderr, "unable to expand '%s'\n", input);

        fclose(outfile);
        unlink(tmpout);

        exit(1);
    }

    fclose(outfile);

    /* Made executable before it is put in place, so that it is never
     * there as a file nobody can run. */
    chmod_size = strlen("chmod oug+x ") + strlen(tmpout) + 1;
    chmod = malloc(chmod_size);
    snprintf(chmod, chmod_size, "chmod oug+x %s", tmpout);
    ret = system(chmod);
    free(chmod);

    /* Whatever system() hands back is a wait status rather than an
     * exit code, so returning it from main() reported a chmod that
     * exited 1 as a pbashc that exited 0.  Nothing here has any use
     * for which signal it was either way. */
    if (ret != 0) {
        fprintf(stderr, "unable to make '%s' executable\n", tmpout);
        unlink(tmpout);
        exit(1);
    }

    if (rename(tmpout, output) != 0) {
        fprintf(stderr, "unable to rename '%s' to '%s'\n", tmpout, output);
        unlink(tmpout);
        exit(1);
    }

    free(tmpout);
    return 0;
}

int write_line(const char *line, void *defs_uncast)
{
    const char **defs = defs_uncast;
    char *new_line = strdup(line);
    while (*defs != NULL) {
        char *old_line = new_line;
        if (strstr(*defs, "=") != NULL) {
            new_line = replace(old_line, *defs);
            free(old_line);
        }
        defs++;
    }

    fputs(new_line, outfile);
    free(new_line);

    return 0;
}

char *replace(const char *line, const char *pair)
{
    char *from, *out;
    const char *to;
    int count;
    size_t ii, oi;

    to = strstr(pair, "=");
    if (to == NULL)
        return strdup(line);

    from = strndup(pair, to - pair);
    to++;

    count = 0;
    for (ii = 0; ii < strlen(line); ++ii)
        if (strncmp(line + ii, from, strlen(from)) == 0)
            count++;

    out = malloc(strlen(line)
                 + (strlen(to) * count)
                 - (strlen(from) * count)
                 + 1);
    if (out == NULL) {
        perror("Unable to malloc()");
        free(from);
        return NULL;
    }

    ii = oi = 0;
    out[0] = '\0';
    while (ii < strlen(line)) {
        if (strncmp(line + ii, from, strlen(from)) == 0) {
            strcat(out + oi, to);
            ii += strlen(from);
            oi += strlen(to);
        } else {
            out[oi] = line[ii];
            oi++;
            ii++;
            out[oi] = '\0';
        }
    }

    free(from);
    return out;
}
