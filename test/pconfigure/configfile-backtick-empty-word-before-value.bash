#include "harness_start.bash"

# A backtick that prints nothing takes itself out of the line, and the
# line it leaves behind is read the way any other line is: the
# whitespace either side of where it was is one gap between words, not
# two.  Left as two, the value after the operator starts with a space,
# so "SOURCES += `true` main.c" names a source called " main.c" -- a
# file nobody has, and a rule make splits back up into targets nobody
# meant.
#
# The usual way to get here is a conditional piece of a line, like
# "`test -n "$DEBUG" && echo -DDEBUG` -O2", that came out empty.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
SOURCES     += `true` main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out

# It's one ordinary file name, so there's nothing to warn about.
if grep -q "space in its name" out
then
    exit 1
fi
if grep -q "src/ main.c" Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/main
