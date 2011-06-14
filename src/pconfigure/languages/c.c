#include "c.h"

#include <stdlib.h>
#include <string.h>

struct language * language_c_boot(void)
{
	struct language_c * out;
	
	out = malloc(sizeof(*out));
	if (out == NULL) return NULL;
	
	out->lang.name = strdup("c");
	
	return (struct language *)out;
}
