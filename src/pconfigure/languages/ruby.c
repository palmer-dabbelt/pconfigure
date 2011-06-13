#include "ruby.h"

#include <stdlib.h>
#include <string.h>

struct language * language_ruby_boot(void)
{
	struct language_ruby * out;
	
	out = malloc(sizeof(*out));
	if (out == NULL) return NULL;
	
	out->lang.name = strdup("ruby");
	
	return (struct language *)out;
}
