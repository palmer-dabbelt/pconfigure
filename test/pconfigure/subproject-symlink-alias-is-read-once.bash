#include "harness_start.bash"

# A pconfigure tree checked out under vendor/ and linked into place at
# the top, with both spellings named -- the manual says a symlink that
# stays inside the project is left alone, since "linking a vendored
# tree into place from elsewhere in the same checkout is a real thing
# to do", and that a project asked for twice is only read once.  That
# has to be decided by the directory rather than the spelling, or
# "vendor/a" and "a" are read as two projects sharing one object
# directory: each writes a rule for the same test result under its own
# name, a parallel "make check" runs both at once and one of them fails
# renaming the other's file, and the report counts one test twice.
mkdir -p vendor/a/test/unit
ln -s vendor/a a

cat >vendor/a/Configfile <<'EOF'
LANGUAGES += bash
PHONY     += unit
TESTSRC   += t.bash
EOF

echo 'exit 0' > vendor/a/test/unit/t.bash

cat >Configfile <<'EOF'
SUBPROJECTS += vendor/a
SUBPROJECTS += a
EOF

$PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1 || { cat configure.out; exit 1; }
cat configure.out

# One project, so one Makefile for it.
ls vendor/a/obj
test "$(ls vendor/a/obj | grep -c '^Makefile\.')" = "1"

make $MAKE_ARGS -j2 check > check.out 2>&1 || { cat check.out; exit 1; }
cat check.out
test "$(grep -c '^CHECK	t.bash$' check.out)" = "1"

ptest="$(dirname "$PTEST_BINARY")/ptest"
$ptest --no-check-make-check > report.out 2>&1 || true
cat report.out
grep -q "^NRUN	1$" report.out

exit 0
