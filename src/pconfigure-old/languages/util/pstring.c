#include "pstring.h"

#include <string.h>

int util_pstring_ends_with(const char *string, const char *ending)
{
    return strcmp(string + strlen(string) - strlen(ending), ending) == 0;
}
