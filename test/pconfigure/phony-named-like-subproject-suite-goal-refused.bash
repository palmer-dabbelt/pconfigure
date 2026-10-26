#include "harness_start.bash"

# A suite a subproject declares gets its "check-<name>" rule written
# into the Makefile at the top as well, since that is the Makefile make
# gets asked for it in.  So a PHONY at the top named after it is the
# same collision as one beside a suite of its own project, even though
# the suite's line is in another Configfile that hasn't been read when
# the PHONY's line is.

mkdir -p src test/t sub/src sub/test/u

cat >Configfile <<'EOF'
SUBPROJECTS += sub

LANGUAGES   += bash
PHONY       += check-net
TESTDEPS    += bin/t

BINARIES    += t
SOURCES     += t.bash
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES     += bash
TEST_SUITES   += net

BINARIES      += u
SOURCES       += u.bash
TESTSRC[net]  += a.bash
EOF

echo 'echo t' > src/t.bash
echo 'echo u' > sub/src/u.bash
echo 'exit 0' > sub/test/u/a.bash

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    echo "PHONY += check-net was accepted beside sub's suite net" >&2
    exit 1
fi
cat configure.out

grep -q "^./Configfile:4" configure.out
grep -qF "error: PHONY can't be called 'check-net'" configure.out
grep -q "sub/Configfile:2.* declares that suite" configure.out
test ! -e Makefile
