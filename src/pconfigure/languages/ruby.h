#ifndef PCONFIGURE_LANGUAGES_RUBY_H
#define PCONFIGURE_LANGUAGES_RUBY_H

#include "language.h"

struct language_ruby
{
	struct language lang;
};

/* This initializes the entire ruby-build subsystem */
struct language * language_ruby_boot(void);

#endif
