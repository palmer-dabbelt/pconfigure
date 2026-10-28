#include "harness_start.bash"

# A TESTSRC is a path too, and the same two spellings of one test made
# two check rules -- check/main/t.bash and check/main/./t.bash -- for
# one tarball.  make runs both, so the test ran twice, and under -j
# the two runs write the same tarball at the same time.  The test
# below counts its own runs to say so.
mkdir -p src test/main
echo 'int main(void) { return 0; }' > src/main.c

cat >test/main/t.bash <<EOF
\$PTEST_BINARY
echo ran >> $tempdir/runs
EOF

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.bash
TESTSRC   += ./t.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

cat runs
test "$(wc -l < runs | tr -d ' ')" = 1
