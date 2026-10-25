#include "harness_start.bash"

# A static archive can't take a LINKOPTS, since it is never linked, but
# a compiled test under one is linked, and may need a library of its
# own.  Written as TESTS with the LINKOPTS above its SOURCES, the
# option lands on the test rather than on the archive: it is accepted,
# and it reaches the test's link line and nothing else.

mkdir -p src test/libfoo.a

cat >Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += libfoo.a
SOURCES   += foo.c

TESTS     += needs-libm
LINKOPTS  += -lm
SOURCES   += t.c
EOF

echo 'int foo(void) { return 7; }' >src/foo.c

cat >test/libfoo.a/t.c <<'EOF'
#include <math.h>
#include <stdlib.h>
int main(int argc, char **argv)
{
    (void)argv;
    /* atoi() keeps the compiler from folding sqrt() away. */
    return (int)sqrt((double)atoi("49") + argc - 1) == 7 ? 0 : 1;
}
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The archive is built without it; the test is linked with it.
grep -- ' -lm' Makefile | grep -q 'needs-libm'
test -z "$(grep -- ' -lm' Makefile | grep -v 'needs-libm')"


make $MAKE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/libfoo.a/needs-libm ptest__return)" = "0"
