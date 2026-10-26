#include "harness_start.bash"

# A '--target' reaches the sub-make's command line as a goal, and make
# decides whether a word there is a goal or a variable by whether it
# has an '=' in it.  So '--target DESTDIR=/tmp/elsewhere' is not a goal
# at all: it is the same variable '--make-var DESTDIR=...' sets, which
# is refused as a second answer to where the tree installs.  kconfig
# asks its '--target' that question for exactly this reason; an
# autotools tree, whose make is run the same way, has to as well.
mkdir -p sub
touch sub/configure.ac

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
CONFIGUREOPTS += --make-var DESTDIR=/tmp/elsewhere
EOF2

# The spelling that is refused today, to be sure the two are compared
# against the same rule.
if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "sets 'DESTDIR'" out

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += autotools
SUBPROJECTS   += sub
CONFIGUREOPTS += --target DESTDIR=/tmp/elsewhere
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    grep -n "DESTDIR=/tmp/elsewhere" Makefile || true
    exit 1
fi
cat out
grep -q "'--target DESTDIR=/tmp/elsewhere' sets 'DESTDIR'" out

exit 0
