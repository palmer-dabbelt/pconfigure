#include "harness_start.bash"

# Nothing about a project's own Configfile has a space in it here: it
# is the directory somebody checked the project out into that does,
# which is not something the project gets a say in.  Building copes
# with that already, since every path in the Makefile is relative.
# Running a test is the one place an absolute path of the project
# gets made -- "--srcdir $(abspath .)", for $PTEST_SRCDIR -- and make
# expands that into the recipe as text, so an unquoted one reaches
# ptest as two arguments and the test never runs.
mkdir -p "my proj/src" "my proj/test/main"
cd "my proj"

echo 'int main(void) { return 0; }' > src/main.c

# The test checks the directory it was handed, too, since one that ran
# with half a path would be a pass that means nothing.
cat >test/main/t.bash <<'EOF'
$PTEST_BINARY
test -f "$PTEST_SRCDIR/Configfile"
EOF

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test "$(tar -xOf check/main/t.bash ptest__return)" = 0
