#include "harness_start.bash"

# File and target names that are more than letters and digits: a
# UTF-8 source name, a target with dashes and dots in it, and a test
# whose name has extra dots.  None of these characters mean anything
# to make or to a shell, so they should go through every rule
# untouched -- built, tested, installed under exactly the name the
# Configfile wrote.
mkdir -p src test/my-tool.v2
echo 'int main(void) { return 0; }' > "src/héllo-wörld.c"
echo '$PTEST_BINARY' > test/my-tool.v2/smoke.test.bash

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += my-tool.v2
SOURCES   += héllo-wörld.c
TESTSRC   += smoke.test.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/my-tool.v2

make $MAKE_ARGS check
test "$(tar -xOf check/my-tool.v2/smoke.test.bash ptest__return)" = 0

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -x dest/usr/local/bin/my-tool.v2
