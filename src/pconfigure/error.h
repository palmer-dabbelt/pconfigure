#ifndef ERRORS_H
#define ERRORS_H

#include <assert.h>

/* A shortcut that does both an assert (for assistance in debugging mode)
   and returns an error (the proper behavior in release mode).  This can be
   turned on by defining DEBUG_RETURNS. */
#ifdef DEBUG_RETURNS
#define RETURN_UNIMPLEMENTED assert(!ERROR_UNIMPLEMENTED); return ERROR_UNIMPLEMENTED;
#define ASSERT_RETURN(s, e) assert(s); if (!(s)) return e;
#else
#define RETURN_UNIMPLEMENTED return ERROR_UNIMPLEMENTED
#define ASSERT_RETURN(s, e) if (!(s)) return e;
#endif

enum error
{
    ERROR_NONE = 0,
    ERROR_UNIMPLEMENTED = 1,
    ERROR_FILE_NOT_FOUND,
    ERROR_NULL_POINTER,
    ERROR_ILLEGAL_OP,
    ERROR_FILE_READ,
    ERROR_ALREADY_BOOT,
    ERROR_MALLOC_NULL,
    ERROR_INTERNAL_STACK
};

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
    case ERROR_NULL_POINTER:
        return
            "ERROR_NULL_POINTER: a NULL pointer was found where not expected";
    case ERROR_ILLEGAL_OP:
        return "ERROR_ILLEGAL_OP: an illegal operation was attempted";
    case ERROR_FILE_READ:
        return
            "ERROR_FILE_READ: an unexpected error was detected while trying to read from a file";
    case ERROR_ALREADY_BOOT:
	return "ERROR_ALREADY_BOOT: this module was already booted";
    case ERROR_MALLOC_NULL:
	return "ERROR_MALLOC_NULL: malloc returned NULL";
    case ERROR_INTERNAL_STACK:
	return "ERROR_INTERNAL_STACK: internal error related to the stack";
    default:
        return "unhandled error code in error_to_string";
    }
}

#endif
