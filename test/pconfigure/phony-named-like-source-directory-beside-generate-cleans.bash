#include "harness_start.bash"

# The same "PHONY += src" beside a GENERATE, asked for "make clean".
# The dependency fragment is an included makefile, so make remakes it
# before it looks at any goal, and with the fragment depending on a
# phony "src" it was never up to date: the clean never started.  A
# tree that can't be cleaned is the one that most needs to be.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += hello
SOURCES   += hello.c

PHONY     += src
EOF2

cat >src/gen.h.proc <<'EOF2'
#!/bin/bash
if test "$1" = "--deps"
then
    exit 0
fi
echo "#define X 0"
EOF2
chmod +x src/gen.h.proc

cat >src/hello.c <<'EOF2'
#include "gen.h"
int main(void) { return X; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

timeout 60 make $MAKE_ARGS clean > clean.out 2>&1 || { tail -20 clean.out; exit 1; }
cat clean.out
test ! -e bin/hello
test ! -e obj/proc/gen.h
