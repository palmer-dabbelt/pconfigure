#include "harness_start.bash"

# A project's suites are a set, and nothing about them depends on
# which line came first: a TESTSRC[quick] and a DEFAULT_TEST_SUITE
# written above the TEST_SUITES line that declares "quick" mean the
# same as they would below it.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES          += bash
DEFAULT_TEST_SUITE  = quick

BINARIES           += t
SOURCES            += t.bash
TESTSRC[quick]     += fast.bash
TESTSRC[slow]      += slow.bash

TEST_SUITES        += quick
TEST_SUITES        += slow
EOF

echo 'echo t' > src/t.bash
echo 'exit 0' > test/t/fast.bash
echo 'exit 0' > test/t/slow.bash

$PTEST_BINARY $PCONFIGURE_ARGS

grep -q "^check: obj/check-suite-quick-report-quiet$" Makefile
grep -q "^obj/check-suite-quick-done: check/t/fast.bash$" Makefile

make $MAKE_ARGS check
test -e check/t/fast.bash
test ! -e check/t/slow.bash

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NRUN	1$" report.out

exit 0
