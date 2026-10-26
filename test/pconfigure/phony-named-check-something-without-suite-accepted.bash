#include "harness_start.bash"

# What's refused is a PHONY that takes a goal some suite actually has,
# not every name that starts with "check-" or "report-".  A
# "check-style" with no suite called "style" is nobody else's goal,
# and a PHONY called after the suite itself -- "quick" beside
# "check-quick" -- is a different name from either of the suite's
# rules.  Both have to keep configuring and building.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES      += bash
TEST_SUITES    += quick

PHONY          += check-style
TESTDEPS       += bin/helper

PHONY          += quick
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

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check-style
test -x bin/helper
make $MAKE_ARGS quick
make $MAKE_ARGS check-quick
