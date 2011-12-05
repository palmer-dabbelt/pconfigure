
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
#include <sys/types.h>
#include <dirent.h>
#include <string.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>

/* Commandline Options */
static bool recurse;

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
            if (recurse == true)
                helper(longname);

        free(longname);
    }

    closedir(dip);
}

int main(int argc, char **argv)
{
    recurse = true;

    if ((argc >= 2) && (strcmp(argv[1], "-r") == 0))
        recurse = false;

    helper(".");

    return 0;
}
