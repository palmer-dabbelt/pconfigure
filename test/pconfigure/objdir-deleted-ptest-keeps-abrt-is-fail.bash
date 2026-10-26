#include "harness_start.bash"

# ABRT_IS_FAIL reaches a bare "ptest" through $OBJDIR/check-dirs, where
# the directory carries an "abrt-is-fail" flag.  Nothing puts that file
# back once the object directory is deleted, so after a rebuild and a
# fresh "make check" the same aborting test that "make report" counts
# as a FAIL is counted by "ptest" as an EROR -- the project's own answer
# to how its asserts are scored is lost without a word.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p src test/main

cat >Configfile <<'EOC'
ABRT_IS_FAIL     = true
LANGUAGES       += c
LANGUAGES       += bash
BINARIES        += main
SOURCES         += main.c
TESTSRC         += asserts.bash
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 'kill -ABRT $$' > test/main/asserts.bash

# ptest, like "make check", exits non-zero when a test failed, which is
# what this tree has; the counts are what is being compared.
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check || true

"$ptest" --no-check-make-check > before.log || true
cat before.log
grep -q "^NFAIL	1$" before.log

rm -rf obj
make $MAKE_ARGS
make $MAKE_ARGS check || true

make $MAKE_ARGS report > report.log || true
cat report.log
grep -q "^NFAIL	1$" report.log

"$ptest" --no-check-make-check > after.log || true
cat after.log
grep -q "^NFAIL	1$" after.log
