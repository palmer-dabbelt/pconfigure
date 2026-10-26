#include "harness_start.bash"

# The suite whose goal a PHONY takes doesn't have to be declared above
# it: a TEST_SUITES further down the Configfile writes the same
# "report-<name>" rule, and the PHONY above it collides with it just
# the same.  So the question can't be answered at the PHONY's line
# alone, and a check that only looked backwards would let this through.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES      += bash
PHONY          += report-slow
TESTDEPS       += bin/t

TEST_SUITES    += slow

BINARIES       += t
SOURCES        += t.bash
TESTSRC[slow]  += a.bash
EOF

echo 'echo t' > src/t.bash
echo 'exit 0' > test/t/a.bash

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += report-slow was accepted above suite slow" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:2" configure.out
grep -qF "error: PHONY can't be called 'report-slow'" configure.out
grep -q "Configfile:5.* declares that suite" configure.out
test ! -e Makefile
