#include "harness_start.bash"

# A DEPLIBS with nothing above it that links -- at the top of a file,
# or under nothing but a LANGUAGES -- is refused.  That refusal is
# about where the line sits in the file, which makes the line number
# the one thing it can't leave out, and the advice differs from the
# DEPLIBS-after-SOURCES case: there is no target one line up to move it
# onto, so it has to say which lines it belongs under.
cat >Configfile <<'EOF2'
# Nothing is open yet, so there is no target for this to land on.

DEPLIBS += m
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >top.out 2>&1
then
    exit 1
fi
cat top.out
grep -q "Attempted to add DEPLIB" top.out
grep -q "Configfile:3" top.out
grep -q "write it below the BINARIES, LIBRARIES, TESTS or GENERATE" top.out
test ! -e Makefile

cat >Configfile <<'EOF2'
LANGUAGES     += c
DEPLIBS       += m
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >language.out 2>&1
then
    exit 1
fi
cat language.out
grep -q "Attempted to add DEPLIB" language.out
grep -q "Configfile:2" language.out
grep -q "write it below the BINARIES, LIBRARIES, TESTS or GENERATE" language.out
test ! -e Makefile
