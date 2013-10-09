
/*
 * Copyright (C) 2013 Palmer Dabbelt
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

#include "ftwfn.h"

static int (*global_fn) (const char *fpath, const struct stat * sb,
                         int typeflag, struct FTW * ftwbuf, void *arg);
static void *global_arg;

static int wrap_fn(const char *fpath, const struct stat *sb,
                   int typeflag, struct FTW *ftwbuf);

int aftw(const char *dirpath,
         int (*fn) (const char *fpath, const struct stat * sb,
                    int typeflag, struct FTW * ftwbuf, void *arg),
         int nopenfd, int flags, void *arg)
{
    global_fn = fn;
    global_arg = arg;
    return nftw(dirpath, &wrap_fn, nopenfd, flags);
}

int wrap_fn(const char *fpath, const struct stat *sb,
            int typeflag, struct FTW *ftwbuf)
{
    return global_fn(fpath, sb, typeflag, ftwbuf, global_arg);
}
