
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

#include "clopts.h"
#include "version.h"
#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif
#include <string.h>

static void setup_infiles(struct clopts *o);

struct clopts *clopts_new(void *ctx, int argc, char **argv)
{
    struct clopts *o;
    int i;

    o = talloc(ctx, struct clopts);
    if (o == NULL)
        return NULL;

    /* Sets the default configuration options */
    o->verbose = false;
    o->outfile = talloc_strdup(o, "Makefile");

    o->source_path = talloc_strdup(o, "");

    o->infiles = NULL;
    setup_infiles(o);

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--verbose") == 0)
            o->verbose = true;
        else if (strcmp(argv[i], "--config") == 0) {
            const char *config;
            const char **infiles;
            int j;

            i++;
            config = argv[i];

            o->infile_count++;

            infiles = talloc_array(o, const char *, o->infile_count);
            for (j = 1; j < o->infile_count; j++)
                infiles[j - 1] = talloc_reference(infiles, o->infiles[j]);

            infiles[0] = talloc_asprintf(infiles, "%sConfigfiles/%s",
                                         o->source_path, config);

            talloc_unlink(o, o->infiles);
            o->infiles = infiles;
        }
        else if (strcmp(argv[i], "--version") == 0) {
            printf("pconfigure %s\n", PCONFIGURE_VERSION);
            TALLOC_FREE(o);
            return NULL;
        }
        else if (strcmp(argv[i], "--sourcepath") == 0) {
            talloc_free((char *)o->source_path);

            if (argv[i + 1][strlen(argv[i + 1]) - 1] != '/')
                o->source_path = talloc_asprintf(o, "%s/", argv[i + 1]);
            else
                o->source_path = talloc_strdup(o, argv[i + 1]);

            setup_infiles(o);

            i++;
        }
        else {
            fprintf(stderr, "Unknown argument: '%s'\n", argv[i]);
            abort();
        }
    }

    if (o->verbose == true)
        for (i = 0; i < o->infile_count; i++)
            printf("Reading '%s'\n", o->infiles[i]);

    return o;
}

void setup_infiles(struct clopts *o)
{
    int i;

    if (o->infiles != NULL)
        talloc_free(o->infiles);

    o->infile_count = 4;

    if (strlen(o->source_path) > 0)
        o->infile_count += 2;

    o->infiles = talloc_array(o, const char *, o->infile_count);
    i = 0;

    /* If we're sourceing from another directory then still allow some
     * flags to be set in this current working directory -- otherwise
     * we'll just end up with _exactly_ the same build every time,
     * which probably isn't the most useful. */
    if (strlen(o->source_path) > 0) {
        o->infiles[i++] = talloc_strdup(o->infiles, "Configfiles/local");
        o->infiles[i++] = talloc_strdup(o->infiles, "Configfile.local");
    }

    o->infiles[i++] = talloc_asprintf(o->infiles, "%sConfigfiles/local",
                                      o->source_path);
    o->infiles[i++] = talloc_asprintf(o->infiles, "%sConfigfile.local",
                                      o->source_path);
    o->infiles[i++] = talloc_asprintf(o->infiles, "%sConfigfiles/main",
                                      o->source_path);
    o->infiles[i++] = talloc_asprintf(o->infiles, "%sConfigfile",
                                      o->source_path);
}
