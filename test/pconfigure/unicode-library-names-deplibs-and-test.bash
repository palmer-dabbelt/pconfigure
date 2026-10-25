#include "harness_start.bash"

# Library names that are more than letters: a shared library whose
# name is UTF-8 and an archive with a dash and dots in its version,
# each found by a DEPLIBS spelled the same way, linked into a program
# whose own name is UTF-8 and which has a test in a UTF-8 directory.
# A DEPLIBS turns into "-l<name>" and a test result into a path under
# check/, and neither should care what the bytes are.
mkdir -p src "test/mäin"
echo 'int f(void) { return 0; }' > src/f.c
echo 'int g(void) { return 0; }' > src/g.c
echo 'int f(void); int g(void); int main(void) { return f() + g(); }' > src/main.c
echo '$PTEST_BINARY' > "test/mäin/tëst.bash"

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libünï.so
SOURCES   += f.c

LIBRARIES += libfoo-1.2.a
SOURCES   += g.c

BINARIES  += mäin
DEPLIBS   += ünï
DEPLIBS   += foo-1.2
SOURCES   += main.c
TESTSRC   += tëst.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
(cd / && "$tempdir/bin/mäin")

make $MAKE_ARGS check
test "$(tar -xOf "check/mäin/tëst.bash" ptest__return)" = 0

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -f "dest/usr/local/lib/libünï.so"
test -f dest/usr/local/lib/libfoo-1.2.a
test -x "dest/usr/local/bin/mäin"
make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
find dest -type f > left
cat left
test ! -s left
