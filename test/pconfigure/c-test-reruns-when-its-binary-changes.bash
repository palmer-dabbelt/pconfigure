#include "harness_start.bash"

# A test's result is about the program it tests, so a rebuilt program
# is an out-of-date result: that is what makes "make check" after an
# edit mean anything.  A BASH test waits on the binary and runs again
# when it changes.  A test written in C is attached to the same binary
# in the same way and has to do the same -- otherwise a fix that broke
# the program leaves the C tests reporting the result they got from
# the program before the fix, and "make check" says nothing is to be
# done.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

BINARIES += t
SOURCES  += t.c
TESTSRC  += counts.c
TESTSRC  += counts.bash
EOF

cat >src/t.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/t/counts.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
int main(void)
{
    char path[4096];
    FILE *f;
    snprintf(path, sizeof(path), "%s/c.log", getenv("PTEST_SRCDIR"));
    f = fopen(path, "a");
    if (f == NULL)
        return 2;
    fprintf(f, "ran\n");
    fclose(f);
    return 0;
}
EOF

cat >test/t/counts.bash <<'EOF'
echo "ran" >> "$PTEST_SRCDIR/bash.log"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS check
test "$(wc -l < c.log | tr -d ' ')" = "1"
test "$(wc -l < bash.log | tr -d ' ')" = "1"

sleep 1
cat >src/t.c <<'EOF'
int main(void) { return 1; }
EOF
make $MAKE_ARGS
make $MAKE_ARGS check

# Both of them, once more each.
test "$(wc -l < bash.log | tr -d ' ')" = "2"
test "$(wc -l < c.log | tr -d ' ')" = "2"

exit 0
