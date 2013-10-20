
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

#ifndef PASS_VCMD_H
#define PASS_VCMD_H

#include "language.h"
#include "context.h"

/* This is a bit of a hack: essentially it's a replacement for the
 * lambda that allows me to redirect calls to makefile_v{add,nam}_cmd
 * depending on what the language wants.  The reason that this is in
 * its own file is because it uses some global data in order to avoid
 * needing to modify language_link() too much. */
extern void language_link_pass_vcmd(struct language *l, struct context *c,
                                    bool to_install);

extern void language_slib_pass_vcmd(struct language *l, struct context *c);

extern void language_build_pass_vcmd(struct language *l, struct context *c);

#endif
