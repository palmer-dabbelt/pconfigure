#include "harness_start.bash"

# $PTEST_BINARY is the absolute path of the program a test is attached
# to, and its directory is $BINDIR: that is the one anchor the manual
# gives a test for finding the rest of its project, and the only way a
# test can run the thing it was written to test.  A BASH test gets
# exactly that.  A test written in C or C++ is a program too, so the
# same TESTSRC under the same BINARIES has to get the same answer --
# not the path of one of the test's own object files, which is neither
# executable nor anywhere near $BINDIR.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += c
LANGUAGES += bash

BINARIES += t
SOURCES  += t.c
TESTSRC  += from-c.c
TESTSRC  += from-bash.bash
EOF

cat >src/t.c <<'EOF'
#include <stdio.h>
int main(void) { puts("I am the program"); return 0; }
EOF

cat >test/t/from-c.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
int main(void)
{
    const char *bin = getenv("PTEST_BINARY");
    char cmd[4096];
    printf("PTEST_BINARY=%s\n", bin);
    snprintf(cmd, sizeof(cmd), "'%s'", bin);
    return system(cmd) == 0 ? 0 : 1;
}
EOF

cat >test/t/from-bash.bash <<'EOF'
echo "PTEST_BINARY=$PTEST_BINARY"
"$PTEST_BINARY"
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

# Run either way: what each test was handed is in its result, and that
# is the question here rather than whether the C one managed to use it.
make $MAKE_ARGS check || true

tar -xOf check/t/from-bash.bash ptest__output > bash.out
tar -xOf check/t/from-c.c ptest__output > c.out
cat bash.out c.out

grep -q "^PTEST_BINARY=$(pwd)/bin/t$" bash.out
grep -q "^PTEST_BINARY=$(pwd)/bin/t$" c.out
grep -q "^I am the program$" c.out
test "$(tar -xOf check/t/from-c.c ptest__return)" = "0"

exit 0
