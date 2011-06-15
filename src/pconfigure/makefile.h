#ifndef PCONFIGURE_MAKEFILE_H
#define PCONFIGURE_MAKEFILE_H

#include <stdio.h>
#include "string_list.h"

struct makefile
{
	FILE * file;
	struct string_list targets_all;
};

void makefile_init(struct makefile * mf);
void makefile_clear(struct makefile * mf);



#endif

