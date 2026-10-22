#include "harness_start.bash"

# A TESTSRC written under a LIBRARIES is a test of that library: it is
# handed the library as $PTEST_BINARY and waits for it to be built.
# Libraries are built into the LIBDIR rather than the BINDIR, so the
# check rule has to name "lib/libx.so"; naming "bin/libx.so" instead
# asks make for a file nothing in the build makes, and "make check"
# stops with "No rule to make target" before running anything.
mkdir -p src test/libx.so

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libx.so
SOURCES   += x.c
TESTSRC   += loads.bash
EOF

echo 'int x(void) { return 0; }' > src/x.c

# What the test was handed has to be the library itself, not merely
# some file that happens to exist.
cat >test/libx.so/loads.bash <<'TEST'
test -f "$PTEST_BINARY"
case "$PTEST_BINARY" in
    */lib/libx.so) ;;
    *) echo "PTEST_BINARY is $PTEST_BINARY, not the library" >&2; exit 1 ;;
esac
TEST

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f lib/libx.so
test ! -e bin/libx.so

make $MAKE_ARGS check
test "$(tar -xOf check/libx.so/loads.bash ptest__return)" = "0"

exit 0
