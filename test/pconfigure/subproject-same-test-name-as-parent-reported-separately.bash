#include "harness_start.bash"

# The top and its subproject each have a test called "unit/t.bash",
# and only the subproject's fails.  Results are kept per project, so
# the two don't overwrite each other: the report lists both, credits
# the failure to the subproject's, and "make check" from the top fails
# because of it.
mkdir -p test/unit sub/test/unit

cat >Configfile <<'EOF'
SUBPROJECTS += sub

LANGUAGES   += bash
PHONY       += unit
TESTSRC     += t.bash
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES += bash
PHONY     += unit
TESTSRC   += t.bash
EOF

echo 'exit 0' > test/unit/t.bash
echo 'exit 1' > sub/test/unit/t.bash

$PTEST_BINARY $PCONFIGURE_ARGS

if make $MAKE_ARGS check > check.out 2>&1
then
    cat check.out
    exit 1
fi
cat check.out

test "$(tar -xOf check/unit/t.bash ptest__return)" = "0"
test "$(tar -xOf sub/check/unit/t.bash ptest__return)" != "0"

ptest="$(dirname "$PTEST_BINARY")/ptest"
$ptest --no-check-make-check > report.out || true
cat report.out
grep -q "^  PASS	unit/t.bash$" report.out
grep -q "^\* FAIL	sub/unit/t.bash$" report.out
grep -q "^NRUN	2$" report.out

exit 0
