#include "harness_start.bash"

# "check-quick" is the goal pconfigure writes for the suite "quick",
# and a PHONY of that name was a second rule for it that make merged
# without a word: asking for the suite also built whatever the PHONY
# stands for, and asking for the PHONY ran the suite.  Two things
# written in the Configfile that answer to one make goal is a collision
# that is named at the PHONY's line, along with the suite's.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES      += bash
TEST_SUITES    += quick
PHONY          += check-quick
TESTDEPS       += bin/helper

BINARIES       += helper
SOURCES        += helper.bash

BINARIES       += t
SOURCES        += t.bash
TESTSRC[quick] += a.bash
EOF

echo 'echo helper' > src/helper.bash
echo 'echo t' > src/t.bash
echo 'exit 0' > test/t/a.bash

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += check-quick was accepted beside suite quick" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:3" configure.out
grep -qF "error: PHONY can't be called 'check-quick'" configure.out
grep -qF "the test suite 'quick'" configure.out
grep -q "Configfile:2.* declares that suite" configure.out
test ! -e Makefile
