#include "harness_start.bash"

# Two names for exactly the same set of tests should give the same
# answer.  Every test here is unnamed, so it is in the "everything"
# suite as well as in "make check".  After a failing test is taken out
# of the Configfile, the suite's report scores the results it was
# named and is green.  The project-wide one used to walk the check
# directory instead, find the departed test's tarball and go red.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES   += bash

TEST_SUITES += everything

BINARIES    += t
SOURCES     += t.bash
TESTSRC     += stays.bash
TESTSRC     += goes.bash
EOF

echo 'echo hello' > src/t.bash
echo 'exit 0' > test/t/stays.bash
echo 'exit 1' > test/t/goes.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check || true

sed -i.bak '/goes.bash/d' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS

suite=0
make $MAKE_ARGS check-everything || suite=$?
all=0
make $MAKE_ARGS check || all=$?

test "$suite" = "0"
test "$all" = "$suite"

exit 0
