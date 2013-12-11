
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

#include "languagelist.h"
#include "lang/c.h"
#include "lang/bash.h"
#include "lang/cxx.h"
#include "lang/asm.h"
#include "lang/scala.h"
#include "lang/chisel.h"
#include "lang/pkgconfig.h"
#include "lang/perl.h"
#include "lang/h.h"
#include "lang/flo.h"
#include <string.h>
#include <assert.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

static struct clopts *o;

struct languagelist *languagelist_new(struct clopts *o_in)
{
    struct languagelist *ll;
    o = o_in;

    ll = talloc(o, struct languagelist);
    if (ll == NULL)
        return NULL;

    ll->head = NULL;

    return ll;
}

int languagelist_select(struct languagelist *ll, const char *name)
{
    struct languagelist_node *cur;
    struct language *l, *l_nonull;

    if (ll == NULL)
        return -1;
    if (name == NULL)
        return -1;

    /* Attempts to find a language already in the list. */
    cur = ll->head;
    while (cur != NULL) {
        if (strcmp(cur->data->name, name) == 0) {
            ll->selected = cur->data;
            break;
        }

        cur = cur->next;
    }
    if (cur != NULL)
        return 0;

    /* The language wasn't already added, so search for it. */
    l_nonull = NULL;
    if ((l = language_c_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_cxx_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_asm_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_bash_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_scala_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_chisel_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_pkgconfig_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_perl_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_h_new(o, name)) != NULL)
        l_nonull = l;
    if ((l = language_flo_new(o, name)) != NULL)
        l_nonull = l;

    /* If no language was found then we have to give up entirely */
    if (l_nonull == NULL)
        return -1;

    /* There was a language found, so add it to the list */
    cur = talloc(ll, struct languagelist_node);
    cur->data = talloc_reference(cur, l_nonull);
    cur->next = ll->head;
    ll->head = cur;
    ll->selected = l_nonull;
    return 0;
}

int languagelist_remove(struct languagelist *ll, const char *name)
{
    struct languagelist_node *cur, *prev;

    if (ll == NULL)
        return -1;
    if (name == NULL)
        return -1;

    /* Attempts to find a language already in the list. */
    prev = NULL;
    cur = ll->head;
    while (cur != NULL) {
        if (strcmp(cur->data->name, name) == 0)
            break;

        prev = cur;
        cur = cur->next;
    }

    /* If the language isn't there then just give up right away. */
    if (cur == NULL)
        return -1;

    if (prev == NULL) {
        ll->head = cur->next;
    } else {
        prev->next = cur->next;
    }

    talloc_free(cur);

    return 0;
}

struct language *languagelist_search(struct languagelist *ll,
                                     struct language *parent,
                                     const char *path, struct context *c)
{
    struct languagelist_node *cur;

    if (ll == NULL)
        return NULL;
    if (path == NULL)
        return NULL;

    cur = ll->head;
    while (cur != NULL) {
        struct language *found;

        found = language_search(cur->data, parent, path, c);
        if (found != NULL)
            return found;

        cur = cur->next;
    }

    return NULL;
}

struct language *languagelist_get(struct languagelist *ll, void *context)
{
    if (ll == NULL)
        return NULL;
    if (ll->selected == NULL)
        return NULL;

    return talloc_reference(context, ll->selected);
}
