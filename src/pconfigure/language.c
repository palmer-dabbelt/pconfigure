
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

int language_init(struct language *l)
{
    if (l == NULL)
        return -1;

    l->name = NULL;
    l->compileopts = stringlist_new(l);
    l->linkopts = stringlist_new(l);

    return 0;
}

int language_add_compileopt(struct language *l, const char *opt)
{
    if (l == NULL)
        return -1;
    if (opt == NULL)
        return -1;
    if (l->compileopts == NULL)
        return -1;

    return stringlist_add(l->compileopts, opt);
}
