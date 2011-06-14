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
};

void target_init(struct target * t);

#endif
