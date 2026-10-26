#include "harness_start.bash"

# An '--autoreconf' is a command line run inside the tree as written.
# One with a quote that never closes makes the rule that makes the
# configure die in the shell with "unexpected EOF" on every make, so
# it has to be refused where it was written, naming the line.
mkdir -p sub
touch sub/configure.ac

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
CONFIGUREOPTS += --autoreconf autoreconf -i 'm4
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep -n "autoreconf -i" Makefile || true
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -q "single quote that never closes" out

exit 0
