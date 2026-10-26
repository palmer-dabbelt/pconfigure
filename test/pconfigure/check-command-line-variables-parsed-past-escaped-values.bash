#include "harness_start.bash"

# ptest finds the variables set on the outer make's command line by
# reading them back out of $MAKEFLAGS, where make escapes a space in a
# value with a backslash: "make check 'SPACED=x KEEP=y'" is the one
# word "SPACED=x\ KEEP=y".  Splitting that on spaces would take KEEP
# for a command-line variable too, and stop exporting a KEEP the test
# had every right to from the environment make itself was run in.
#
# PATH stays exported whatever the command line said, because it is
# how a test finds the tools it is meant to run, so "make check
# PATH=..." is a choice that should reach it.  A command-line "out"
# must leave the test like any other name, but it must not take
# ptest's own "out", its record of where to put the result, with it.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += bash

BINARIES  += t
SOURCES   += t.bash
TESTSRC   += env.bash
EOF

echo 'echo hello' > src/t.bash

cat >test/t/env.bash <<'EOF'
env > "$PTEST_TMPDIR/env"
exit 0
EOF

mkdir -p "$tempdir/bin"
$PTEST_BINARY $PCONFIGURE_ARGS
KEEP=from-environment make $MAKE_ARGS check \
    'SPACED=x KEEP=y' 'BACKSLASH=a\ CAUGHT=1' APPENDED+=z COLON:=w \
    out=nowhere PATH="$tempdir/bin:$PATH"

tar -xOf check/t/env.bash env > env.out

grep -E "^(SPACED|KEEP|BACKSLASH|CAUGHT|APPENDED|COLON|out)=" env.out || true

for leaked in SPACED BACKSLASH APPENDED COLON out
do
    if grep -q "^$leaked=" env.out
    then
        exit 1
    fi
done

grep -qx "KEEP=from-environment" env.out
grep -q "^PATH=$tempdir/bin:" env.out

exit 0
