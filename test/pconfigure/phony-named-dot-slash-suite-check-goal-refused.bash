#include "harness_start.bash"

# A "./" in front of a suite's goal is no different to make from the
# bare name: "PHONY += ./check-q" beside "TEST_SUITES += q" wrote
# "./check-q" next to "check-q", which make reads as one rule, so
# running the suite built the PHONY's TESTDEPS too and asking for the
# PHONY ran the suite.  It is refused like the bare spelling, at the
# PHONY's line and naming the suite's.

mkdir -p src test/t

cat >Configfile <<'EOC'
LANGUAGES      += bash
TEST_SUITES    += q
PHONY          += ./check-q
TESTDEPS       += bin/helper

BINARIES       += helper
SOURCES        += helper.bash

BINARIES       += t
SOURCES        += t.bash
TESTSRC[q]     += a.bash
EOC

echo 'echo helper' > src/helper.bash
echo 'echo t' > src/t.bash
echo 'exit 0' > test/t/a.bash

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += ./check-q was accepted beside suite q" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:3" configure.out
grep -qF "error: PHONY can't be called './check-q': make reads that as 'check-q'" configure.out
grep -qF "the test suite 'q'" configure.out
grep -q "Configfile:2.* declares that suite" configure.out
test ! -e Makefile
