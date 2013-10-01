
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

#include "liblist.h"

#include <stdlib.h>
#include <string.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

struct liblist *liblist_new(void *context)
{
    struct liblist *l;

    l = talloc(context, struct liblist);
    l->head = NULL;

    return l;
}

int liblist_add(struct liblist *l, const char *name)
{
    if (l->head == NULL) {
        l->head = talloc(l, struct liblist_node);
        l->head->next = NULL;
        l->head->name = talloc_reference(l->head, name);
        l->head->deps = stringlist_new(l->head);
    } else {
        struct liblist_node *cur;

        cur = l->head;
        while (cur->next != NULL)
            cur = cur->next;

        cur->next = talloc(l, struct liblist_node);
        cur->next->next = NULL;
        cur->next->name = talloc_reference(cur->next, name);
        cur->next->deps = stringlist_new(cur->next);
    }

    return 0;
}

int liblist_add_dep_ifnew(struct liblist *l, const char *n, const char *dep)
{
    struct liblist_node *cur;

    cur = l->head;
    while (cur != NULL) {
        if (strcmp(cur->name, n) == 0) {
            return stringlist_add_ifnew(cur->deps, dep);
        }

        cur = cur->next;
    }

    return -1;
}

int liblist_each(struct liblist *l, const char *name,
                 int (*func) (const char *))
{
    struct liblist_node *cur;

    cur = l->head;
    while (cur != NULL) {
        int out;

        if (strcmp(cur->name, name) == 0) {
            out = stringlist_each(cur->deps, func);
            if (out != 0)
                return out;
        }

        cur = cur->next;
    }

    return 0;
}
