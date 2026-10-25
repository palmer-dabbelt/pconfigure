#include "harness_start.bash"

# DEFAULT_TEST_SUITE names a suite, and a suite is everything it
# includes as well as everything that joined it -- so a "make check"
# that means a suite which includes another runs both sets of tests,
# and "make report" reports both.  What neither suite reaches stays
# unrun, which is the reason for having a default suite at all.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES          += bash
DEFAULT_TEST_SUITE  = everywhere

TEST_SUITES         += offline
TEST_SUITES         += everywhere
INCLUDE_TEST_SUITES += offline
TEST_SUITES         += network

BINARIES            += t
SOURCES             += t.bash
TESTSRC[offline]    += offline.bash
TESTSRC[everywhere] += everywhere.bash
TESTSRC[network]    += network.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

for name in offline everywhere network
do
    echo 'exit 0' > test/t/$name.bash
done

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check

test -f check/t/offline.bash
test -f check/t/everywhere.bash
test ! -e check/t/network.bash

make $MAKE_ARGS report > report.out
cat report.out
grep -q "PASS	t/offline.bash" report.out
grep -q "PASS	t/everywhere.bash" report.out
grep -q "^NRUN	2$" report.out

# The bare ptest asks make about the suite's stamp, which this run
# just built, so it has nothing to warn about.
ptest="$(dirname "$PTEST_BINARY")/ptest"
"$ptest" > bare.out
cat bare.out
if grep -q "WARNING" bare.out
then
    exit 1
fi

exit 0
