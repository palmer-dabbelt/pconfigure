#include "harness_start.bash"

# A TESTSRC can sit in a directory of its own under the target's test
# directory, and the compile half already knows: pbashc's output goes
# to obj/check/main/nested/, with that directory made first.  The
# check half has to know too.  Its tarball is check/main/nested/
# deep.bash, and making only check/main -- the target's check
# directory -- leaves ptest writing into a directory that isn't
# there, so the test never gets a result at all.
ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p src test/main/nested
echo 'int main(void) { return 0; }' > src/main.c
echo '$PTEST_BINARY' > test/main/nested/deep.bash
echo '$PTEST_BINARY' > test/main/top.bash

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += nested/deep.bash
TESTSRC   += top.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test -f check/main/nested/deep.bash
test "$(tar -xOf check/main/nested/deep.bash ptest__return)" = 0
test "$(tar -xOf check/main/top.bash ptest__return)" = 0

# And the report finds it where it was put: both tests, both passing.
$ptest --no-check-make-check > report
cat report
grep -q "PASS.*nested/deep.bash" report
grep -q "^NFAIL[[:space:]]*0$" report
