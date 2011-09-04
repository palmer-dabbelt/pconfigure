#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>

#include "defaults.h"
#include "errors.h"

/* Functions for parsing the different types of options availiable in pconfigure
   files.  These all return 1 on failure. */
typedef int (*parsefunc) (char *, char *);

static enum error parsefunc_languages(char *, char *);
static enum error parsefunc_prefix(char *, char *);
static enum error parsefunc_compileopts(char *, char *);
static enum error parsefunc_linkopts(char *, char *);
static enum error parsefunc_targets(char *, char *);
static enum error parsefunc_sources(char *, char *);

/* Selects the correct parsing function to use, calls it, and gets returns
   what it returns */
static enum error select_parsefunc(char *, char *, char *);

/* Parses an entire file, returning 0 on success, 1 on failure, and 2 on
   file-not-found (or otherwise not readable) */
static enum error parse_file(const char *file_name);
static enum error parse_line(const char *line, char *left, char *op,
                             char *right);

int main(int argc, char **argv)
{
    enum error err;

    /* Checks if we were called with any arguments, and if so dies */
    if (argc != 1)
    {
        fprintf(stderr, "%s: Palmer's Makefile Generator\n", argv[0]);
        return 1;
    }

    /* Parses the two given files */
    err = parse_file(DEFAULT_INFILE_LOCAL);
    if (err != ERROR_FILE_NOT_FOUND)
    {
        printf("pconfigure failed on file %s\n", DEFAULT_INFILE_LOCAL);
        return 1;
    }

    err = parse_file(DEFAULT_INFILE);
    if (err != ERROR_NONE)
    {
        printf("pconfigure failed on file %s\n"
               "error %d: %s\n", DEFAULT_INFILE, err, error_to_string(err));
    }

    return err;
}

/*
 *	File main loop and string tokenizer
 */
enum error parse_file(const char *file_name)
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

enum error parse_line(const char *line, char *left, char *op, char *right)
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
enum error select_parsefunc(char *left, char *op, char *right)
{
    if (strlen(left) == 0)
        return 0;
    if (strcmp(left, "LANGUAGES") == 0)
        return parsefunc_languages(op, right);
    if (strcmp(left, "PREFIX") == 0)
        return parsefunc_prefix(op, right);
    if (strcmp(left, "COMPILEOPTS") == 0)
        return parsefunc_compileopts(op, right);
    if (strcmp(left, "LINKOPTS") == 0)
        return parsefunc_linkopts(op, right);
    if (strcmp(left, "TARGETS") == 0)
        return parsefunc_targets(op, right);
    if (strcmp(left, "SOURCES") == 0)
        return parsefunc_sources(op, right);

    return ERROR_UNIMPLEMENTED;
}

enum error parsefunc_languages(char *op, char *right)
{
    return ERROR_UNIMPLEMENTED;
}

enum error parsefunc_prefix(char *op, char *right)
{
    return ERROR_UNIMPLEMENTED;
}

enum error parsefunc_compileopts(char *op, char *right)
{
    return ERROR_UNIMPLEMENTED;
}

enum error parsefunc_linkopts(char *op, char *right)
{
    return ERROR_UNIMPLEMENTED;
}

enum error parsefunc_targets(char *op, char *right)
{
    return ERROR_UNIMPLEMENTED;
}

enum error parsefunc_sources(char *op, char *right)
{
    return ERROR_UNIMPLEMENTED;
}
