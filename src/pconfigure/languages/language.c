
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

#include "language.h"

#include <stdlib.h>

#include "../error.h"
#include "../string_list.h"

enum error language_init(struct language *l)
{
    enum error err;

    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);

    l->name = NULL;
    l->extension = NULL;

    l->compile_str = NULL;
    l->link_str = NULL;
    l->compile_cmd = NULL;
    l->link_cmd = NULL;

    l->compile_opts = malloc(sizeof(*(l->compile_opts)));
    ASSERT_RETURN(l->compile_opts != NULL, ERROR_MALLOC_NULL);
    err = string_list_init(l->compile_opts);
    CHECK_ERROR(err);

    l->link_opts = malloc(sizeof(*(l->link_opts)));
    ASSERT_RETURN(l->link_opts != NULL, ERROR_MALLOC_NULL);
    err = string_list_init(l->link_opts);
    CHECK_ERROR(err);

    l->search = NULL;
    l->write = NULL;

    return ERROR_NONE;
}

enum error language_clear(struct language *l)
{
    enum error err;

    ASSERT_RETURN(l != NULL, ERROR_NULL_POINTER);

    err = string_list_clear(l->compile_opts);
    if (err != ERROR_NONE)
        return err;
    free(l->compile_opts);

    err = string_list_clear(l->link_opts);
    if (err != ERROR_NONE)
        return err;
    free(l->link_opts);

    return ERROR_NONE;
}
