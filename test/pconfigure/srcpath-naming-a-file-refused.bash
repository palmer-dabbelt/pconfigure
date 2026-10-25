#include "harness_start.bash"

# The same mistake as a "--srcpath" naming nothing, made with a path
# that does exist but is a file: pointing it at the Configfile itself
# rather than the directory that holds it is the easy way to get
# there.  Nothing can be read from under a file, so it configured an
# empty project just the same.  It gets refused, and the message says
# it isn't a directory, since "doesn't exist" would send whoever reads
# it looking for a file that is right there.
mkdir -p checkout/src build

cat >checkout/Configfile <<'EOF2'
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF2

echo 'int main(void) { return 0; }' > checkout/src/main.c

if (cd build && $PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout/Configfile) >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e build/Makefile
grep -q "checkout/Configfile', which isn't a directory" out

# The directory it was meant to be still works, so the refusal is
# about the path rather than about anything in the tree.
cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout
make $MAKE_ARGS
test -x bin/main
