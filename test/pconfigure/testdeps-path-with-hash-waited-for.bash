#include "harness_start.bash"

# A TESTDEPS is a path that goes onto the test's check rule as a
# prerequisite, and a '#' on a rule line starts a comment: make was
# handed "test/data", a file nobody named, and "make check" stopped on
# "No rule to make target 'test/data'", which says nothing about the
# TESTDEPS that caused it.  The path has to be written so that make
# reads it back as the file it is, and then a test waits on it like
# any other.
#
# One bash test and one C test, because languages/bash.c++ and
# languages/cxx.c++ each write their own check rule, and a PHONY with
# the same TESTDEPS because languages/phony.c++ writes a third.

mkdir -p src test/main

cat >Configfile <<'EOC'
LANGUAGES   += c
LANGUAGES   += bash
BINARIES    += main
TESTDEPS    += test/data#1.txt
SOURCES     += main.c
TESTSRC     += reads-data.bash
TESTSRC     += also-runs.c

PHONY       += data
TESTDEPS    += test/data#1.txt
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo hello > 'test/data#1.txt'

cat >test/main/reads-data.bash <<'EOC'
#!/bin/bash
exit 0
EOC

cat >test/main/also-runs.c <<'EOC'
int main(void) { return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS check
test "$(tar -xOf check/main/reads-data.bash ptest__return)" = "0"
test "$(tar -xOf check/main/also-runs.c ptest__return)" = "0"
make $MAKE_ARGS data

# And it is that file, rather than merely something make is content
# with: changing it runs both tests again.
sleep 1
echo goodbye > 'test/data#1.txt'
make $MAKE_ARGS check > second.out
cat second.out
grep -q "CHECK.reads-data.bash" second.out
grep -q "CHECK.also-runs.c" second.out
