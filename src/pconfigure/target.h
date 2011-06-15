#ifndef PCONFIGURE_TARGET_H
#define PCONFIGURE_TARGET_H

enum target_type
{
	TARGET_TYPE_NONE,
	TARGET_TYPE_BIN,
	TARGET_TYPE_INC,
	TARGET_TYPE_LIB,
	TARGET_TYPE_MAN,
	TARGET_TYPE_SHR,
	TARGET_TYPE_ETC,
	TARGET_TYPE_SRC
};

struct target
{
	enum target_type type;
	
	char * target;
	char * source;
	struct target * parent;
};

/* Starts out with an empty target, or sets an existing target to be
   empty.  Targets should be empty before messing with them. */
int target_init(struct target * t);
int target_clear(struct target * t);

/* Flushes the current target out to a makefile.  This will not clear the
   target, that must be done later.  */
int target_flush(struct target * t);

/* Fills in targets of the different types, these will not clear a target
   but instead will error out. */
int target_set_bin(struct target * t, const char * target);
int target_set_src(struct target * t, const char * source,
									 struct target * parent);



#endif

