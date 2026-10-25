#include "harness_start.bash"

# A BASH test of a C program is compiled without the program's
# COMPILEOPTS: a "-DGREETING=hello" that the C code is built with
# would otherwise be a text substitution pbashc makes all through the
# test, rewriting its own words.  The test runs against the C program
# it was written for.
mkdir -p src test/app

cat >Configfile <<'EOF'
LANGUAGES   += c
LANGUAGES   += bash

BINARIES    += app
COMPILEOPTS += -DGREETING=hello
SOURCES     += app.c
TESTSRC     += greets.bash
EOF

cat >src/app.c <<'EOF'
#include <stdio.h>
int main(void) { puts("hi"); return 0; }
EOF

cat >test/app/greets.bash <<'EOF'
test "$($PTEST_BINARY)" = hi
test "GREETING" = "GREETING"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
grep -q '^test "GREETING" = "GREETING"$' obj/check/app/greets.bash
test "$(tar -xOf check/app/greets.bash ptest__return)" = 0
