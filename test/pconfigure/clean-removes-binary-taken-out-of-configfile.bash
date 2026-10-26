#include "harness_start.bash"

# make clean already removes the whole check directory rather than the
# results the Configfile names today, because a test taken out of the
# Configfile left its result behind and nothing short of distclean
# would ever take it.  A program taken out has the same problem: the
# Makefile no longer names bin/old, so its clean rule doesn't either,
# and cache-clean only looks inside the object directory.  The stale
# program stays on disk -- and on the PATH of anything that runs the
# tree's bin/ -- until a distclean.

mkdir -p src

echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOC'
LANGUAGES += c
BINARIES  += old
SOURCES   += main.c
BINARIES  += keep
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x bin/old
test -x bin/keep

cat >Configfile <<'EOC'
LANGUAGES += c
BINARIES  += keep
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS clean

test ! -e bin/keep
test ! -e bin/old
