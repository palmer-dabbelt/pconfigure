
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef PBASHC_SHEBANG
#define PBASHC_SHEBANG "#!/bin/bash\n"
#endif

int main(int argc, char **argv)
{
    char *input;
    char *output;
    char *last;
    int i;
    FILE *infile;
    FILE *outfile;
    char buffer[1024];
    int read;
    char *chmod;
    int chmod_size;

    input = NULL;
    output = NULL;
    last = NULL;

    for (i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "-o") == 0)
            last = argv[i];
        else if (last == NULL)
            input = argv[i];
        else if (strcmp(last, "-o") == 0)
        {
            output = argv[i];
            last = NULL;
        }
    }

    if ((input == NULL) || (output == NULL))
    {
        fprintf(stderr, "needs 2 arguments\ninput '%s'\noutput '%s'\n",
                input, output);
        exit(1);
    }

    infile = fopen(input, "r");
    outfile = fopen(output, "w");

    fprintf(outfile, PBASHC_SHEBANG "\n");

    while ((read = fread(buffer, 1, 1024, infile)) != 0)
        if (fwrite(buffer, 1, read, outfile) != read)
            exit(1);

    fclose(infile);
    fclose(outfile);

    chmod_size = strlen("chmod oug+x ") + strlen(output) + 1;
    chmod = malloc(chmod_size);
    snprintf(chmod, chmod_size, "chmod oug+x %s", output);
    return system(chmod);
}
