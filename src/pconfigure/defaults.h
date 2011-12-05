
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

#ifndef PCONFIGURE_DEFAULTS_H
#define PCONFIGURE_DEFAULTS_H

#define MAX_LINE_SIZE		1024

#define DEFAULT_INFILE          "Configfile"
#define DEFAULT_INFILE_LOCAL    "Configfile.local"

#define DEFAULT_OUTFILE         "Makefile"

#define DEFAULT_CONTEXT_CURDIR	"."
#define DEFAULT_CONTEXT_PREFIX	"/usr/local"
#define DEFAULT_CONTEXT_BINDIR	"bin"
#define DEFAULT_CONTEXT_INCDIR	"inc"
#define DEFAULT_CONTEXT_LIBDIR	"lib"
#define DEFAULT_CONTEXT_MANDIR	"man"
#define DEFAULT_CONTEXT_SHRDIR	"share"
#define DEFAULT_CONTEXT_ETCDIR	"etc"
#define DEFAULT_CONTEXT_SRCDIR	"src"
#define DEFAULT_CONTEXT_OBJDIR	"obj"

#ifdef PCONFIGURE_DEFAULTS_C
char *default_context_prefix;
#else
extern char *default_context_prefix;
#endif

extern void defaults_boot(void);

#endif
