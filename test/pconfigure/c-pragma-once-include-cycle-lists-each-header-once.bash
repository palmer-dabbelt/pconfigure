#include "harness_start.bash"

# Two headers that include each other under "#pragma once" are a
# perfectly ordinary thing to compile.  The scan for what a source
# reads doesn't read the pragma, so all that stops it going around the
# cycle forever is refusing to go back into a header it is still in
# the middle of.  This is the C side of the same scan a bash script's
# includes go through.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += tool
SOURCES   += main.c
EOF2

cat >src/main.c <<'EOF2'
#include "a.h"
int main(void) { return A_VALUE + B_VALUE - 3; }
EOF2

cat >src/a.h <<'EOF2'
#pragma once
#include "b.h"
#define A_VALUE 1
EOF2

cat >src/b.h <<'EOF2'
#pragma once
#include "a.h"
#define B_VALUE 2
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/tool

# The object's rule names each header once, rather than however many
# times the scan managed to go around before something gave out.
for h in src/a.h src/b.h; do
    n="$(grep -h "^obj/.*main\.c.*:" Makefile | tr ' ' '\n' | grep -cx "$h")"
    test "$n" = 1
done

# Editing the header reached only through the other one rebuilds.
sleep 1
sed -i 's/B_VALUE 2/B_VALUE 3/' src/b.h
make $MAKE_ARGS
if ./bin/tool; then exit 1; fi
exit 0
