
/*
 * Copyright (C) 2011 Daniel Dabbelt
 *   <palmem@comcast.net>
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

#define CHECK_ERROR(err) ASSERT_RETURN(err == ERROR_NONE, err)

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
    ERROR_INTERNAL_STACK,
    ERROR_ALREADY_EXISTS,
    ERROR_INTERNAL_STATE
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
    case ERROR_ALREADY_EXISTS:
        return "ERROR_ALREADY_EXISTS: a unique identifier already exists";
    case ERROR_INTERNAL_STATE:
        return "ERROR_INTERNAL_STATE: improper state for this operation";
    }

    return "error in error_string()";
}

#endif
