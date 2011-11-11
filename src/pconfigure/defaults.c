#define PCONFIGURE_DEFAULTS_C
#include "defaults.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void defaults_boot(void)
{
    default_context_prefix = strdup(DEFAULT_CONTEXT_PREFIX);
}
