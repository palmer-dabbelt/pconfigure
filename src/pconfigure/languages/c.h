#ifndef PCONFIGURE_LANGUAGES_C_H
#define PCONFIGURE_LANGUAGES_C_H

#include "language.h"

struct language_c
{
	struct language lang;
};

/* This initializes the entire GCC subsystem */
struct language * language_c_boot(void);

#endif
