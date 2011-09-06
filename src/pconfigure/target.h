#ifndef TARGET_H
#define TARGET_H

#include "error.h"
#include "string_list.h"

enum target_type
{
    TARGET_TYPE_NONE = 0,
    TARGET_TYPE_BINARY,
    TARGET_TYPE_SOURCE
};

/* Holds a single "target" (which can be a TARGET, SOURCE, etc) */
struct target
{
    /* Targets are a n-tree that goes from child->parent (so the reverse mapping
     * is stored) */
    struct target *parent;

    /* Targets all have a type */
    enum target_type type;

    /* The path passed when this target was created */
    char * passed_path;

    /* The actual full path to the source (or binary, or library, etc) that
       this target represents */
    char * full_path;

    /* Targets can have their own options */
    struct string_list * compile_opts;
    struct string_list * link_opts;
};

/* Initializes the target module */
enum error target_boot(void);

/* Initializes a single target, starts as completely empty */
enum error target_init(struct target * t);

/* Clears out a target, writing the required bits to the makefile in order
   to actually build the target. */
enum error target_clear(struct target *t);

/* Copies target "source" into target "dest" */
enum error target_copy(struct target *dest, struct target *source);

#endif
