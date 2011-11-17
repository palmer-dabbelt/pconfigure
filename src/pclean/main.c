#include <stdio.h>
#include <sys/types.h>
#include <dirent.h>
#include <string.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <unistd.h>

static void helper(const char *name)
{
    DIR *dip;
    struct dirent *dit;

    dip = opendir(name);

    while ((dit = readdir(dip)) != NULL)
    {
        struct stat statbuf;
        char *longname;

        if (dit->d_name[0] == '.')
            continue;

        longname = malloc(strlen(name) + strlen(dit->d_name) + 3);
        longname[0] = '\0';
        strcat(longname, name);
        strcat(longname, "/");
        strcat(longname, dit->d_name);

        stat(longname, &statbuf);

        if (longname[strlen(longname) - 1] == '~')
        {
            printf("Cleaning '%s'\n", longname);
            unlink(longname);
        }

        if (S_ISDIR(statbuf.st_mode))
            helper(longname);

        free(longname);
    }

    closedir(dip);
}

int main(int argc, char **argv)
{
    helper(".");

    return 0;
}
