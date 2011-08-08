#include "context.h"
#include "string_list.h"
#include "language_list.h"
#include "defaults.h"
#include "target.h"

#include <stdlib.h>
#include <assert.h>

#define _GNU_SOURCE
#include <string.h>
#undef _GNU_SOURCE

void context_init(struct context *context)
{
    assert(context != NULL);

    context->cur_dir = strdup(DEFAULT_CONTEXT_CURDIR);
    context->prefix = strdup(DEFAULT_CONTEXT_PREFIX);
    context->bin_dir = strdup(DEFAULT_CONTEXT_BINDIR);
    context->inc_dir = strdup(DEFAULT_CONTEXT_INCDIR);
    context->lib_dir = strdup(DEFAULT_CONTEXT_LIBDIR);
    context->man_dir = strdup(DEFAULT_CONTEXT_MANDIR);
    context->shr_dir = strdup(DEFAULT_CONTEXT_SHRDIR);
    context->etc_dir = strdup(DEFAULT_CONTEXT_ETCDIR);
    context->src_dir = strdup(DEFAULT_CONTEXT_SRCDIR);
    context->obj_dir = strdup(DEFAULT_CONTEXT_OBJDIR);

    string_list_init(&(context->compile_opts));
    string_list_init(&(context->link_opts));

    context->languages = malloc(sizeof(*context->languages));
    assert(context->languages != NULL);
    language_list_init(context->languages);

    context->target = malloc(sizeof(*context->target));
    assert(context->target != NULL);
    target_init(context->target);
}
