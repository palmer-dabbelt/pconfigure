#ifndef PCONFIGURE_LANGUAGES_GCC_H
#define PCONFIGURE_LANGUAGES_GCC_H

#include "language.h"

struct language_gcc
{
	struct language lang;
};

/* This initializes the entire GCC subsystem */
struct language * language_gcc_boot(void);

#endif
