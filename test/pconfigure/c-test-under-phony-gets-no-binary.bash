#include "harness_start.bash"

# A test hung off a PHONY has no program to test, and a BASH one is
# told so with an empty $PTEST_BINARY and no --bin at all.  A test
# written in C under the same PHONY is in the same position and has to
# hear the same thing, rather than being handed something of its own
# that happens to be lying around -- one of its own object files, say
# -- dressed up as the program under test.

mkdir -p test/integration

cat >Configfile <<'EOF'
LANGUAGES += c

PHONY     += integration
TESTSRC   += nothing.c
EOF

cat >test/integration/nothing.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
int main(void)
{
    const char *bin = getenv("PTEST_BINARY");
    printf("PTEST_BINARY=%s\n", bin == NULL ? "" : bin);
    return (bin == NULL || bin[0] == '\0') ? 0 : 1;
}
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# No --bin on the command line, because there is nothing to name.
grep -q "ptest' --test obj/check/integration/nothing.c --out check/integration/nothing.c --srcdir" Makefile
if grep -q -- "--out check/integration/nothing.c --bin" Makefile
then
    exit 1
fi

make $MAKE_ARGS
make $MAKE_ARGS check || true
tar -xOf check/integration/nothing.c ptest__output
test "$(tar -xOf check/integration/nothing.c ptest__return)" = "0"

exit 0
