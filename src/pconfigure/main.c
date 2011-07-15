#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>

#include "defaults.h"
#include "context_stack.h"
#include "makefile.h"

/* The global context stack for the entire parser */
static struct context_stack cstack;

/* We always output to only one makefile */
static struct makefile mf;

/* Functions for parsing the different types of options availiable in pconfigure
   files.  These all return 1 on failure. */
typedef int (*parsefunc) (char *, char *);

static int parsefunc_languages(char *, char *);
static int parsefunc_prefix(char *, char *);
static int parsefunc_compileopts(char *, char *);
static int parsefunc_targets(char *, char *);
static int parsefunc_sources(char *, char *);

/* Selects the correct parsing function to use, calls it, and gets returns
   what it returns */
static int select_parsefunc(char *, char *, char *);

/* Parses an entire file, returning 0 on success, 1 on failure, and 2 on
   file-not-found (or otherwise not readable) */
static int parse_file(const char *file_name);
static int parse_line(const char *line, char *left, char *op, char *right);

int main(int argc, char **argv)
{
    int err;

    /* Checks if we were called with any arguments, and if so dies */
    if (argc != 1)
    {
        fprintf(stderr, "%s: Palmer's Makefile Generator\n", argv[0]);
        return 1;
    }

    /* Sets up the initial context and the context stack */
    context_stack_init(&cstack);

    /* Initializes the list of languages the system can support */
    language_list_boot();

    /* Starts an empty makefile */
    makefile_init(&mf);

    /* Parses the two given files */
    if (parse_file(DEFAULT_INFILE_LOCAL) == 1)
    {
        printf("pconfigure failed on file %s\n", DEFAULT_INFILE_LOCAL);
        return 1;
    }

    err = parse_file(DEFAULT_INFILE);
    if (err != 0)
        makefile_clear(&mf);

    if (err == 2)
        printf("Unable to read %s\n", DEFAULT_INFILE);
    if (err == 1)
        printf("pconfigure failed on file %s\n", DEFAULT_INFILE);

    return err;
}

/*
 *	File main loop and string tokenizer
 */
int parse_file(const char *file_name)
{
    FILE *file;
    char line[MAX_LINE_SIZE];
    char left[MAX_LINE_SIZE], op[MAX_LINE_SIZE], right[MAX_LINE_SIZE];
    unsigned int line_num;

    file = fopen(file_name, "r");
    if (file == NULL)
        return 2;

    /* Reads the entire file */
    line_num = 1;
    while (fgets(line, MAX_LINE_SIZE, file) != NULL)
    {
        int err;

        err = parse_line(line, left, op, right);
        if (err != 0)
        {
            fprintf(stderr, "Read error %d on line %d of %s:\n\t%s",
                    err, line_num, file_name, line);
            return err;
        }

        err = select_parsefunc(left, op, right);
        if (err != 0)
        {
            fprintf(stderr, "Parse error %d on line %d of %s:\n\t%s",
                    err, line_num, file_name, line);
            return err;
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

/*
 *	Function for parsing specific commands
 */
int select_parsefunc(char *left, char *op, char *right)
{
    if (strlen(left) == 0)
        return 0;
    if (strcmp(left, "LANGUAGES") == 0)
        return parsefunc_languages(op, right);
    if (strcmp(left, "PREFIX") == 0)
        return parsefunc_prefix(op, right);
    if (strcmp(left, "COMPILEOPTS") == 0)
        return parsefunc_compileopts(op, right);
    if (strcmp(left, "TARGETS") == 0)
        return parsefunc_targets(op, right);
    if (strcmp(left, "SOURCES") == 0)
        return parsefunc_sources(op, right);

    return 1;
}

int parsefunc_languages(char *op, char *right)
{
    if (strcmp(op, "+=") == 0)
        return language_list_add(&(context_stack_peek(&cstack)->languages),
                                 right);
    if (strcmp(op, "-=") == 0)
        return language_list_remove(&(context_stack_peek(&cstack)->languages),
                                    right);

    return 1;
}

int parsefunc_prefix(char *op, char *right)
{
    struct context *c;

    if (strcmp(op, "=") != 0)
        return 1;

    c = context_stack_peek(&cstack);
    assert(c != NULL);
    free(c->prefix);
    c->prefix = strdup(right);

    return 0;
}

int parsefunc_compileopts(char *op, char *right)
{
    struct context *c;

    c = context_stack_peek(&cstack);
    assert(c != NULL);

    if (strcmp(op, "+=") == 0)
        return string_list_addifnew(&(c->compile_opts), right);
    if (strcmp(op, "-=") == 0)
        return string_list_remove(&(c->compile_opts), right);

    return 0;
}

int parsefunc_targets(char *op, char *right)
{
    struct context *c;

    if (strcmp(op, "+=") != 0)
        return 1;

    c = context_stack_peek(&cstack);
    assert(c != NULL);

    target_flush(&(c->target));
    target_clear(&(c->target));
    target_set_bin(&(c->target), right);

    return 0;
}

int parsefunc_sources(char *op, char *right)
{
    struct context *c;
    struct target t;
    int err;

    if (strcmp(op, "+=") != 0)
        return 1;

    err = target_init(&t);
    if (err != 0)
        return err;

    err = target_set_src(&t, right, &(c->target), &(c->languages));
    if (err != 0)
        return err;

    err = target_flush(&t);
    if (err != 0)
        return err;

    return 0;
}
