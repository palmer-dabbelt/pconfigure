#include "harness_start.bash"

# The same thing through make: a test that ends by taking every
# permission off its own $PTEST_TMPDIR -- the strongest version of
# "check the program copes with a directory it can't touch" -- has
# finished, and finished passing.  ptest can neither write the status
# into the directory nor enter it, so it exits 1, the check target
# fails, make stops before the report, and the test has no result at
# all.  A sibling test that left a read-only subdirectory behind is
# already handled; the directory itself is the case left over.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += locks-tmpdir.bash
TESTSRC   += plain.bash
EOF

echo 'echo hello' > src/t.bash

cat >test/t/locks-tmpdir.bash <<'EOF'
chmod 000 "$PTEST_TMPDIR"
exit 0
EOF

cat >test/t/plain.bash <<'EOF'
exit 0
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test "$(tar -xOf check/t/locks-tmpdir.bash ptest__return)" = "0"

make $MAKE_ARGS report > report.out
cat report.out
grep -q "^NPASS	2$" report.out

exit 0
