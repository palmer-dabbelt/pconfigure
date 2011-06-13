#ifndef CONTEXT_H
#define CONTEXT_H

#include "string_list.h"
#include "language_list.h"
#include "target.h"

/* Stores all the context of a single pconfigure instance.  Note that all
   pointers here need to be free'd whenever they are changed, and should be
   free'able because the context stack will free them on pop's. */
struct context
{
	/* The current working directory, relative to where pconfigure was called
	   from.  This is not always "./" because we have the INCLUDE operation. */
	char * cur_dir;
	
	/* The prefix to use to install things into */
	char * prefix;

	/* Directories where different types of targets will go.  These are relative
     to CWD for the build step, and to PREFIX for the install step */
	char * bin_dir;
	char * inc_dir;
	char * lib_dir;
	char * man_dir;
	char * shr_dir;
	char * etc_dir;
	char * src_dir;
	
	/* Contains a list of the current compilation options */
	struct string_list compile_opts;
	struct string_list link_opts;
	
	/* Lists all the languages that could possibly be used by the current
		 context */
	struct language_list languages;
	
	/* The current target that will get built into */
	struct target target;
};

/* Initializes a context to have all default values */
void context_init(struct context * context);

#endif
