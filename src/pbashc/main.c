#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char ** argv)
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

    fprintf(outfile, "#!/bin/bash\n");

    while ((read = fread(buffer, 1, 1024, infile)) != 0)
	fwrite(buffer, 1, read, outfile);

    fclose(infile);
    fclose(outfile);

    chmod_size = strlen("chmod oug+x ") + strlen(output) + 1;
    chmod = malloc(chmod_size);
    snprintf(chmod, chmod_size, "chmod oug+x %s", output);
    return system(chmod);
}
