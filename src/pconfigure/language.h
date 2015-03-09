
/*
 * Copyright (C) 2011 Palmer Dabbelt
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

#ifndef PCONFIGURE_LANGUAGE_H
#define PCONFIGURE_LANGUAGE_H

#include "stringlist.h"
#include "context.h"
#include "makefile.h"
#include <assert.h>
#include <stdbool.h>

struct language
{
    char *name;
    char *link_name;

    char *compile_str;
    char *compile_cmd;
    char *link_str;
    char *link_cmd;

    /* Shared Object Extension (so for C, jar for Java).  The
     * canonical name is always "so" for C (regardles of platform),
     * while the non-canonical name varies ("dynlib" on OSX, for
     * example). */
    char *so_ext;
    char *so_ext_canon;

    /* Static object extension (a for C).  AFAIK these two are always
     * the same, but that's probably just because I haven't build
     * static libraries on OSX. */
    char *a_ext;
    char *a_ext_canon;

    struct stringlist *compile_opts;
    struct stringlist *link_opts;

    bool compiled;

    /* This is TRUE if this language cares about the difference
     * between shared and static libraries. */
    bool cares_about_static;

    struct language *(*search) (struct language *, struct language *,
                                const char *, struct context *);
    const char *(*objname) (struct language *, void *, struct context *);
    void (*deps) (struct language *, struct context *,
                  void (*)(void *, const char *, ...), void *);
    void (*build) (struct language *, struct context *,
                   void (*)(bool, const char *, ...));
    void (*link) (struct language *, struct context *,
                  void (*)(bool, const char *, ...), bool);
    void (*slib) (struct language *, struct context *,
                  void (*)(bool, const char *, ...));
    void (*extras) (struct language *, struct context *, void *,
                    void (*)(void *, const char *), void *);
    void (*quirks) (struct language *, struct context *, struct makefile *);
};

extern int language_init(struct language *l);

extern int language_set_compiler(struct language *l, char *cmd);
extern int language_set_linker(struct language *l, char *cmd);

extern int language_add_compileopt(struct language *l, const char *opt);
extern int language_add_linkopt(struct language *l, const char *opt);

extern struct language *language_search(struct language *l,
                                        struct language *parent,
                                        const char *path, struct context *c);
extern const char *language_objname(struct language *l, void *context,
                                    struct context *c);

extern bool language_needs_compile(struct language *l, struct context *c);

extern void language_deps(struct language *l, struct context *c,
                          void (*func) (void *, const char *, ...), void *);
extern void language_build(struct language *l, struct context *c,
                           void (*func) (bool, const char *, ...));
extern void language_link(struct language *l, struct context *c,
                          void (*func) (bool, const char *, ...),
                          bool for_install);
extern void language_slib(struct language *l, struct context *c,
                          void (*func) (bool, const char *, ...));
extern void language_extras(struct language *l, struct context *c, void *cxt,
                            void (*func) (void *, const char *), void *arg);
extern void language_quirks(struct language *l, struct context *c,
                            struct makefile *mf);

#endif
