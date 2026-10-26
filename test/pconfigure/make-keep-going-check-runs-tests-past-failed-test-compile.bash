#include "harness_start.bash"

# "make -k check" with one compiled test that doesn't compile.  The C
# and BASH check targets are written by two different backends, and
# each test hangs only off what it needs, so make -k still runs every
# other test -- the BASH one and the C one that compiles -- and leaves
# their results, while the run as a whole fails and no report claims
# that everything passed.

mkdir -p src test/hello

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash

BINARIES  += hello
SOURCES   += hello.c
TESTSRC   += broken.c
TESTSRC   += fine.c
TESTSRC   += runs.bash
EOF2

echo 'int main(void) { return 0; }' > src/hello.c
echo 'int main(void) { return 0 }' > test/hello/broken.c
echo 'int main(void) { return 0; }' > test/hello/fine.c
echo '"$PTEST_BINARY"' > test/hello/runs.bash

$PTEST_BINARY $PCONFIGURE_ARGS

if make $MAKE_ARGS -k check > check.out 2>&1
then
    cat check.out
    exit 1
fi
cat check.out

test "$(tar -xOf check/hello/runs.bash ptest__return)" = "0"
test "$(tar -xOf check/hello/fine.c ptest__return)" = "0"
test ! -e check/hello/broken.c
test ! -e obj/check-report-quiet

exit 0
