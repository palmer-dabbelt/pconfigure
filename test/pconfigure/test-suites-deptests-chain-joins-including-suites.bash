#include "harness_start.bash"

# An unnamed test is in every suite it could run in, and a test that
# waits for another can only run where that one does.  Through a chain
# -- "parse" waits for "fetch-index", which waits for "download", which
# only the network suite has -- that is the network suite, and every
# suite that includes it, and no other.  The suite that has nothing to
# do with the network keeps only its own test.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES           += bash

TEST_SUITES         += nightly
INCLUDE_TEST_SUITES += network
TEST_SUITES         += network
TEST_SUITES         += offline

BINARIES            += t
SOURCES             += t.bash
TESTSRC[network]    += download.bash
TESTSRC             += fetch-index.bash
DEPTESTS            += download.bash
TESTSRC             += parse.bash
DEPTESTS            += fetch-index.bash
TESTSRC[offline]    += lint.bash
EOF

echo 'echo t' > src/t.bash
for x in download fetch-index parse lint
do
    echo 'exit 0' > "test/t/$x.bash"
done

$PTEST_BINARY $PCONFIGURE_ARGS

grep -q "^obj/check-suite-network-done: check/t/download.bash check/t/fetch-index.bash check/t/parse.bash$" Makefile
grep -q "^obj/check-suite-nightly-done: check/t/download.bash check/t/fetch-index.bash check/t/parse.bash$" Makefile
grep -q "^obj/check-suite-offline-done: check/t/lint.bash$" Makefile

make $MAKE_ARGS check-offline
test -e check/t/lint.bash
test ! -e check/t/parse.bash
test ! -e check/t/fetch-index.bash
test ! -e check/t/download.bash

make $MAKE_ARGS check-nightly
make $MAKE_ARGS report-nightly > nightly.out
cat nightly.out
grep -q "^NRUN	3$" nightly.out

exit 0
