#include "harness_start.bash"

# An INCLUDE_TEST_SUITES names a suite, and what it brings in is every
# test in that suite -- including the ones that suite got by including
# others.  So inclusion is transitive, and a ring of three suites that
# each include the next is three names for one set.  A fourth suite
# that includes any one of the ring gets all of it plus its own.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES           += bash

TEST_SUITES         += a
INCLUDE_TEST_SUITES += b
TEST_SUITES         += b
INCLUDE_TEST_SUITES += c
TEST_SUITES         += c
INCLUDE_TEST_SUITES += a

TEST_SUITES         += d
INCLUDE_TEST_SUITES += a

BINARIES            += t
SOURCES             += t.bash
TESTSRC[a]          += a.bash
TESTSRC[b]          += b.bash
TESTSRC[c]          += c.bash
TESTSRC[d]          += d.bash
EOF

echo 'echo t' > src/t.bash
for x in a b c d
do
    echo 'exit 0' > "test/t/$x.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS

for s in a b c
do
    grep -q "^obj/check-suite-$s-done: check/t/a.bash check/t/b.bash check/t/c.bash$" Makefile
done
grep -q "^obj/check-suite-d-done: check/t/a.bash check/t/b.bash check/t/c.bash check/t/d.bash$" Makefile

make $MAKE_ARGS check-b
test -e check/t/a.bash
test -e check/t/b.bash
test -e check/t/c.bash
test ! -e check/t/d.bash

make $MAKE_ARGS report-d > d.out
cat d.out
grep -q "^NRUN	4$" d.out

exit 0
