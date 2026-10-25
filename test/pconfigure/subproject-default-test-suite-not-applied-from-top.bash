#include "harness_start.bash"

# A subproject's DEFAULT_TEST_SUITE says what "make check" means
# inside that subproject.  The top has no DEFAULT_TEST_SUITE, and
# there "make check" means every test the build has -- the
# subproject's slow ones included, which is why a failing slow test
# fails the top's check while the subproject's own check passes.
mkdir -p test/unit sub/test/unit

cat >Configfile <<'EOF'
SUBPROJECTS += sub

LANGUAGES   += bash
PHONY       += unit
TESTSRC     += t.bash
EOF

cat >sub/Configfile <<'EOF'
TEST_SUITES        += quick
TEST_SUITES        += slow
DEFAULT_TEST_SUITE  = quick

LANGUAGES          += bash
PHONY              += unit
TESTSRC[quick]     += q.bash
TESTSRC[slow]      += s.bash
EOF

echo 'exit 0' > test/unit/t.bash
echo 'exit 0' > sub/test/unit/q.bash
echo 'exit 1' > sub/test/unit/s.bash

$PTEST_BINARY $PCONFIGURE_ARGS
if make $MAKE_ARGS check > top.out 2>&1
then
    cat top.out
    exit 1
fi
cat top.out
test -f check/unit/t.bash
test -f sub/check/unit/q.bash
test -f sub/check/unit/s.bash
test "$(tar -xOf sub/check/unit/s.bash ptest__return)" != "0"

# Inside, configured on its own, the subproject's own default holds.
rm -rf sub/check
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)
(cd sub && make $MAKE_ARGS check)
test -f sub/check/unit/q.bash
test ! -e sub/check/unit/s.bash

exit 0
