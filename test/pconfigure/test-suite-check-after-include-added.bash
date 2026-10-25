#include "harness_start.bash"

# An INCLUDE_TEST_SUITES line is a change to which tests a suite
# holds, said without touching any test.  Adding one has to make the
# including suite's "make check-<suite>" about the larger set: the
# tests it pulls in may well have run already, under their own suite,
# but the including suite has never reported on them -- and when one
# of them failed, a "make check-<suite>" that says there's nothing to
# be done is a pass for a suite with a failure in it.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES   += bash
TEST_SUITES += network
TEST_SUITES += everything

BINARIES            += t
SOURCES             += t.bash
TESTSRC[everything] += passes.bash
TESTSRC[network]    += fails.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/passes.bash <<'EOF'
exit 0
EOF

cat >test/t/fails.bash <<'EOF'
exit 1
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

if make $MAKE_ARGS check-network
then
    exit 1
fi
sleep 1
make $MAKE_ARGS check-everything

sleep 1
cat >>Configfile <<'EOF'

TEST_SUITES         += everything
INCLUDE_TEST_SUITES += network
EOF
$PTEST_BINARY $PCONFIGURE_ARGS

if make $MAKE_ARGS report-everything > report.out
then
    exit 1
fi
cat report.out
grep -q "FAIL	t/fails.bash" report.out

if make $MAKE_ARGS check-everything > check.out 2>&1
then
    cat check.out
    exit 1
fi
cat check.out
grep -q "FAIL	t/fails.bash" check.out

exit 0
