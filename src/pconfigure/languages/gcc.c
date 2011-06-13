#include "gcc.h"

#include <stdlib.h>
#include <string.h>

struct language * language_gcc_boot(void)
{
	struct language_gcc * out;
	
	out = malloc(sizeof(*out));
	if (out == NULL) return NULL;
	
	out->lang.name = strdup("gcc");
	
	return (struct language *)out;
}
