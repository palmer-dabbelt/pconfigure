
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

#ifndef FTWFN_H
#define FTWFN_H

#define _XOPEN_SOURCE 500
#include <ftw.h>

/* This is a replacement for nftw that takes an argument pointer that
 * is passed to every invocation.  Note that the current
 * implementation is NOT thread-safe! */
int aftw(const char *dirpath,
         int (*fn) (const char *fpath, const struct stat * sb,
                    int typeflag, struct FTW * ftwbuf, void *arg),
         int nopenfd, int flags, void *arg);

#endif
