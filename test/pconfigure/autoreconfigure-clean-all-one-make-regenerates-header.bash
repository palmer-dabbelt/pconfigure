#include "harness_start.bash"

# The GENERATE spelling of the same thing: under AUTORECONFIGURE,
# hello.c's dependency fragment names obj/proc/gen.h, so make settles
# whether gen.h is current while remaking its makefiles, before any
# goal runs.  "make clean all" then deletes it under "clean" and
# compiles hello.c under "all" without generating it again.  The same
# tree without AUTORECONFIGURE, or "make clean; make", rebuilds fine.

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES       += c

GENERATE        += gen.h

BINARIES        += hello
SOURCES         += hello.c
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
make $MAKE_ARGS -j1
./bin/hello

make $MAKE_ARGS -j1 clean all
./bin/hello

exit 0
