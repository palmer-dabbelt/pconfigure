#include "harness_start.bash"

# A test is read before anything else looks at it, for the
# "#pconfigure" lines it carries, and that read used to take a bash
# test's "#if" for C's.  A comment that happens to start with the word
# then went to the expression reader, which aborted with something
# about a function called "you" and no file or line to go looking at.
# A bash test is a script pbashc expands like any other, so the "#if"
# is refused the way a script's is, at the test and the line it's on.
mkdir -p src test/tool

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
TESTSRC   += t.bash
EOF2

cat >src/tool.bash <<'EOF2'
echo tool
EOF2

cat >test/tool/t.bash <<'EOF2'
echo hi
#if you want more output
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out

grep -q "^test/tool/t\.bash:2: '#if you want more output' can't be used in a script" pconfigure.out
grep -q "or '# if' with a space if this is a comment" pconfigure.out

# Written the way it says, it's a comment, and the test runs.
cat >test/tool/t.bash <<'EOF2'
echo hi
# if you want more output
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(tar -xOf check/tool/t.bash ptest__return)" = 0
