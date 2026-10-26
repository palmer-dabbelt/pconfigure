#include "harness_start.bash"

# "PHONY += src" and "PHONY += include" are natural names for "make
# src" and "make include", and they share a name with the directories
# the build reads.  Under AUTORECONFIGURE the dependency fragments
# name the headers and scripts a source reads, never the directories
# they are in, so a phony with a directory's name leaves the build
# settled: a second make has nothing to do, for C and for BASH.

mkdir -p src include

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES       += c
LANGUAGES       += bash

BINARIES        += hello
SOURCES         += hello.c

BINARIES        += script
SOURCES         += script.bash

PHONY           += src
PHONY           += include
EOF2

cat >src/hello.c <<'EOF2'
#include "x.h"
int main(void) { return 0; }
EOF2
echo '' > include/x.h
cat >src/script.bash <<'EOF2'
#include "lib.bash"
echo script
EOF2
echo 'true' > src/lib.bash

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
timeout 60 make $MAKE_ARGS > again.out 2>&1
cat again.out
grep -q "Nothing to be done" again.out
timeout 60 make $MAKE_ARGS src include
test "$(./bin/script)" = "script"

exit 0
