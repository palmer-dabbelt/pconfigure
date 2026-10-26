#include "harness_start.bash"

# "make clean check" -- start over and run the tests -- in one make,
# on an AUTORECONFIGURE tree whose program reads a HEADERSRC copy.
# The copy is settled as present while make remakes the dependency
# fragments, removed by "clean", and never copied again, so the
# program never builds and no test runs.

mkdir -p src test/hello

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES       += c
LANGUAGES       += h
LANGUAGES       += bash

HEADERSRC       += x.h

BINARIES        += hello
SOURCES         += hello.c
TESTSRC         += runs.bash
EOF2

echo 'int x(void);' > src/x.h
cat >src/hello.c <<'EOF2'
#include <x.h>
int main(void) { return 0; }
EOF2
echo '"$PTEST_BINARY"' > test/hello/runs.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS -j1 check

make $MAKE_ARGS -j1 clean check
test -f check/hello/runs.bash
test "$(tar -xOf check/hello/runs.bash ptest__return)" = "0"

exit 0
