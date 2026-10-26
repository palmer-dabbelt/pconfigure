#include "harness_start.bash"

# A bare "ptest" reports on every project in the build because pconfigure
# writes the list of check directories to $OBJDIR/check-dirs.  That file
# is written by the configure and by nothing else -- unlike the
# configure-time files the build reads, it has no rule that puts it back
# -- so deleting the object directory, which the manual says costs "a
# rebuild of what was in there and nothing more", also costs ptest the
# subproject.  After the rebuild and a fresh "make check", "make report"
# still lists the subproject's failing test, while "ptest" says
# everything passed.

ptest="$(dirname "$PTEST_BINARY")/ptest"

mkdir -p src test/top sub/src sub/test/subbin

cat >Configfile <<'EOC'
SUBPROJECTS     += sub
LANGUAGES       += c
LANGUAGES       += bash
BINARIES        += top
SOURCES         += top.c
TESTSRC         += passes.bash
EOC

cat >sub/Configfile <<'EOC'
LANGUAGES       += c
LANGUAGES       += bash
BINARIES        += subbin
SOURCES         += subbin.c
TESTSRC         += fails.bash
EOC

echo 'int main(void) { return 0; }' > src/top.c
echo 'int main(void) { return 0; }' > sub/src/subbin.c
echo 'exit 0' > test/top/passes.bash
echo 'exit 1' > sub/test/subbin/fails.bash

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
