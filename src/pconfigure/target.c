#include "target.h"

#include <stdlib.h>

void target_init(struct target * t)
{
	t->type = TARGET_TYPE_NONE;
	
	t->target = NULL;
}
