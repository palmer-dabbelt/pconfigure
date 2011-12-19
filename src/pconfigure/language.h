
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

#ifndef PCONFIGURE_LANGUAGE_H
#define PCONFIGURE_LANGUAGE_H

#include "stringlist.h"
#include "context.h"
#include <assert.h>
#include <stdbool.h>

struct language
{
    const char *name;

    const char *compile_str;
    const char *compile_cmd;
    const char *link_str;
    const char *link_cmd;

    struct stringlist *compile_opts;
    struct stringlist *link_opts;

    bool compiled;

    struct language *(*search) (struct language *, struct language *,
                                const char *);
    const char *(*objname) (struct language *, void *, struct context *);
    void (*deps) (struct language *, struct context *,
                  void (*)(const char *, ...));
    void (*build) (struct language *, struct context *,
                   void (*)(bool, const char *, ...));
    void (*link) (struct language *, struct context *,
                  void (*)(bool, const char *, ...));
    void (*extras) (struct language *, struct context *, void *,
                    void (*)(const char *));
};

extern int language_init(struct language *l);

extern int language_add_compileopt(struct language *l, const char *opt);
extern int language_add_linkopt(struct language *l, const char *opt);

extern struct language *language_search(struct language *l,
                                        struct language *parent,
                                        const char *path);
extern const char *language_objname(struct language *l, void *context,
                                    struct context *c);

extern bool language_needs_compile(struct language *l, struct context *c);

extern void language_deps(struct language *l, struct context *c,
                          void (*func) (const char *, ...));
extern void language_build(struct language *l, struct context *c,
                           void (*func) (bool, const char *, ...));
extern void language_link(struct language *l, struct context *c,
                          void (*func) (bool, const char *, ...));
extern void language_extras(struct language *l, struct context *c, void *cxt,
                            void (*func) (const char *));

#endif
