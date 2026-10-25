#include "harness_start.bash"

# The case "-U" exists for: a define every C target gets from a
# language-wide COMPILEOPTS, and one target that wants it gone.  The
# language's options go on the command line ahead of the target's, so
# the compiler sees "-DTRACE ... -UTRACE" and TRACE is undefined.  The
# scan keeps TRACE defined, so the "#ifndef TRACE" branch -- the one
# the compiler takes -- is the one it skips: the header there isn't a
# prerequisite and the source behind it never gets linked, so the
# program doesn't link.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c
COMPILEOPTS += -DTRACE

BINARIES    += app
COMPILEOPTS += -UTRACE
SOURCES     += main.c
EOF

echo 'int quiet(void);' >src/quiet.h
echo 'int quiet(void) { return 6; }' >src/quiet.c

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifndef TRACE
#include "quiet.h"
#endif
int main(void) { printf("%d\n", quiet()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/quiet.h

make $MAKE_ARGS
test "$(./bin/app)" = "6"
