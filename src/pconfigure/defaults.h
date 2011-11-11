#ifndef PCONFIGURE_DEFAULTS_H
#define PCONFIGURE_DEFAULTS_H

#define MAX_LINE_SIZE		1024

#define DEFAULT_INFILE          "Configfile"
#define DEFAULT_INFILE_LOCAL    "Configfile.local"

#define DEFAULT_OUTFILE         "Makefile"

#define DEFAULT_CONTEXT_CURDIR	"."
#define DEFAULT_CONTEXT_PREFIX	"/usr/local"
#define DEFAULT_CONTEXT_BINDIR	"bin"
#define DEFAULT_CONTEXT_INCDIR	"inc"
#define DEFAULT_CONTEXT_LIBDIR	"lib"
#define DEFAULT_CONTEXT_MANDIR	"man"
#define DEFAULT_CONTEXT_SHRDIR	"share"
#define DEFAULT_CONTEXT_ETCDIR	"etc"
#define DEFAULT_CONTEXT_SRCDIR	"src"
#define DEFAULT_CONTEXT_OBJDIR	"obj"

#ifdef PCONFIGURE_DEFAULTS_C
char *default_context_prefix;
#else
extern char *default_context_prefix;
#endif

extern void defaults_boot(void);

#endif
