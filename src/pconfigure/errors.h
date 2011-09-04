#ifndef ERRORS_H
#define ERRORS_H

#include <assert.h>

enum error
{
    ERROR_NONE,
    ERROR_UNIMPLEMENTED,
    ERROR_FILE_NOT_FOUND
};

#define ERROR_NONE 0
#define ERROR_UNIMPLEMENTED 1
#define ERROR_FILE_NOT_FOUND 2

static inline char *error_to_string(enum error error)
{
    assert(error != ERROR_NONE);

    switch (error)
    {
    case ERROR_NONE:
        return "ERROR_NONE means success";
    case ERROR_UNIMPLEMENTED:
        return
            "ERROR_UNIMPLEMENTED: the requested functionality has not yet been implemented";
    case ERROR_FILE_NOT_FOUND:
        return "ERROR_FILE_NOT_FOUND: the requested file was not readable";
    default:
        return "unhandled error code in error_to_string";
    }
}

#endif
