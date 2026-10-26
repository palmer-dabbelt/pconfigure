#include "harness_start.bash"

# A TESTDEPS names a file the test needs built first, spelled the
# ordinary way.  With "LIBDIR = lib/" the library's rule is for
# "lib//libf.so", which make treats as a different file from
# "lib/libf.so", so a fresh "make check" stopped on "No rule to make
# target 'lib/libf.so'".  A trailing slash on PREFIX is dropped for
# just this reason; a LIBDIR needs the same, or a TESTDEPS spelled
# either way has to find the library.
mkdir -p src test/main
echo 'int f(void) { return 3; }' > src/f.c
echo 'int main(void) { return 0; }' > src/main.c
echo 'test -f lib/libf.so' > test/main/has-lib.bash

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash
LIBDIR     = lib/

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += main
TESTDEPS  += lib/libf.so
SOURCES   += main.c
TESTSRC   += has-lib.bash
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test -f lib/libf.so
test "$(tar -xOf check/main/has-lib.bash ptest__return)" = "0"
