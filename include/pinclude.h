
/*
 * Copyright (C) 2013,2016 Palmer Dabbelt
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

#ifndef PINCLUDE_H
#define PINCLUDE_H

/* Lists the files included by a given source file. */
typedef int (*pinclude_callback_t) (const char *filename, void *priv);
int pinclude_list(const char *filename, pinclude_callback_t cb, void *priv,
                  const char **include_dirs, const char **defined);

typedef int (*pinclude_lineback_t) (const char *line, void *priv);
int pinclude_lines(const char *filename,
                   pinclude_callback_t per_include, void *include_priv,
                   pinclude_lineback_t per_line, void *line_priv,
                   const char **include_dirs, const char **defined);

#endif
