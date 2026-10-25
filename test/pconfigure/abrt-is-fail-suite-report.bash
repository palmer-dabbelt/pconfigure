#include "harness_start.bash"

# ABRT_IS_FAIL is about this project's check directory, and a suite's
# report reads the same results out of the same directory -- only
# handed them one at a time rather than walking down to them.  So an
# assert inside a suite is a FAIL in "make report-<suite>" exactly as
# it is in "make report", and a crash of a different kind is still an
# EROR in both.

mkdir -p src test/t

cat >Configfile <<'EOF'
ABRT_IS_FAIL = true

LANGUAGES   += bash
TEST_SUITES += asserts

BINARIES         += t
SOURCES          += t.bash
TESTSRC[asserts] += aborts.bash
TESTSRC[asserts] += segfaults.bash
TESTSRC[asserts] += passes.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/aborts.bash <<'EOF'
kill -ABRT $$
EOF

cat >test/t/segfaults.bash <<'EOF'
kill -SEGV $$
EOF

cat >test/t/passes.bash <<'EOF'
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q -- "--abrt-is-fail-dir check --check-suite asserts" Makefile

make $MAKE_ARGS
if make $MAKE_ARGS check-asserts > check.out 2>&1
then
    exit 1
fi
cat check.out

for rule in report-asserts report
do
    if make $MAKE_ARGS $rule > $rule.out 2>&1
    then
        exit 1
    fi
    cat $rule.out
    grep -q "FAIL	t/aborts.bash" $rule.out
    grep -q "EROR	t/segfaults.bash" $rule.out
    grep -q "PASS	t/passes.bash" $rule.out
    grep -q "^NFAIL	1$" $rule.out
    grep -q "^NEROR	1$" $rule.out
done

exit 0
