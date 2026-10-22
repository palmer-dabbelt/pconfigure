#include "harness_start.bash"

# A library's test waits on the library wherever the LIBDIR put it.
# The directory comes from the LIBDIR rather than being spelled "lib":
# a project that moves its libraries somewhere else needs its library
# tests to follow them there.
mkdir -p src test/libx.so

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

LIBDIR     = mylib

LIBRARIES += libx.so
SOURCES   += x.c
TESTSRC   += loads.bash
EOF

echo 'int x(void) { return 0; }' > src/x.c

cat >test/libx.so/loads.bash <<'TEST'
test -f "$PTEST_BINARY"
case "$PTEST_BINARY" in
    */mylib/libx.so) ;;
    *) echo "PTEST_BINARY is $PTEST_BINARY, not the library" >&2; exit 1 ;;
esac
TEST

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f mylib/libx.so

make $MAKE_ARGS check
test "$(tar -xOf check/libx.so/loads.bash ptest__return)" = "0"

exit 0
