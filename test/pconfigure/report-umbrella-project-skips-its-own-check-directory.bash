#include "harness_start.bash"

# A project that only pulls in subprojects builds nothing and runs no
# tests of its own, so it has no check directory: "make distclean"
# knows that and leaves a "check/" at its top alone.  The report has
# to agree.  A hand-written "check/" there -- a common name for a
# directory of checklists or conformance data -- isn't results, and
# reading it as results scores every file in it as an EROR and turns
# "make check" red while the one real test passed.

mkdir -p check sub/src sub/test/t
echo "release checklist" > check/README

cat >Configfile <<'EOF2'
LANGUAGES   += bash
SUBPROJECTS += sub
EOF2

cat >sub/Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += passes.bash
EOF2

echo 'echo hello' > sub/src/t.bash
echo 'exit 0' > sub/test/t/passes.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NRUN	1$" report.out
grep -q "^NEROR	0$" report.out
if grep -q README report.out
then
    exit 1
fi

# A bare "ptest" reads the list pconfigure wrote down, and that list
# has to say the same thing the Makefile does.
ptest="$(dirname "$PTEST_BINARY")/ptest"
"$ptest" --no-check-make-check > ptest.out
cat ptest.out
grep -q "^NRUN	1$" ptest.out
grep -q "^NEROR	0$" ptest.out

# And distclean still agrees that the directory isn't the build's.
make $MAKE_ARGS distclean
test -e check/README

exit 0
