#include "harness_start.bash"

# "make install" is for what a user of the package wants, and nothing
# a test needs is that: a TESTEXECS -- a C one or a bash one -- is
# built for the tests and never installed, and neither is the
# compiled copy of a TESTSRC.  An install doesn't run the tests
# either, or build the things only they need: a "make install" on a
# tree nobody has built yet leaves no check results and no testexec
# directory behind.
mkdir -p src test/main

echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > src/helper.c
echo 'echo helping' > src/helper-script.bash
echo 'exit 0' > test/main/main-works.bash

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += main-works.bash

TESTEXECS += helper
SOURCES   += helper.c

TESTEXECS += tools/helper-script
SOURCES   += helper-script.bash
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

find dest -type f | sort > installed
cat installed
echo dest/usr/local/bin/main > expected
diff -u expected installed

test ! -e check
test ! -e testexec

# Building them afterwards changes nothing about what is installed.
make $MAKE_ARGS
make $MAKE_ARGS check
test -x testexec/helper
test -x testexec/tools/helper-script
make $MAKE_ARGS DESTDIR=$tempdir/dest install
find dest -type f | sort > installed
diff -u expected installed
