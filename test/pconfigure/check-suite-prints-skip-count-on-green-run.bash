#include "harness_start.bash"

# The same for a suite, and for the suite "make check" means under
# DEFAULT_TEST_SUITE: each writes its quiet report out of the same
# rule, so each held the NSKIP line and showed it only when the run
# failed.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES          += bash

TEST_SUITES        += quick
DEFAULT_TEST_SUITE  = quick

BINARIES           += t
SOURCES            += t.bash
TESTSRC[quick]     += skips.bash
EOF

echo 'echo hello' > src/t.bash
cat >test/t/skips.bash <<'EOF'
echo "SKIP: no cross compiler"
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS check-quick > suite.out 2>&1
cat suite.out
grep -q "^NSKIP	1$" obj/check-suite-quick-report-quiet
grep -q "^NSKIP	1$" suite.out

# Removing the report is what makes "make check" score the suite again
# rather than find it current.
rm -f obj/check-suite-quick-report-quiet
make $MAKE_ARGS check > check.out 2>&1
cat check.out
grep -q "^NSKIP	1$" check.out
