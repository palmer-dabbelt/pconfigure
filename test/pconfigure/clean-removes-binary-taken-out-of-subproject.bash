#include "harness_start.bash"

# A program dropped from a subproject's Configfile is the same stale
# output as one dropped from the top, and "make clean" at the top is
# what has to take it: the clean rule for it is written into the
# subproject's Makefile, which the top one includes and names its
# paths through a variable.

mkdir -p sub/src

echo 'int main(void) { return 0; }' > sub/src/main.c

cat >Configfile <<'EOC'
SUBPROJECTS += sub
EOC

cat >sub/Configfile <<'EOC'
LANGUAGES += c
BINARIES  += old
SOURCES   += main.c
BINARIES  += keep
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -x sub/bin/old

cat >sub/Configfile <<'EOC'
LANGUAGES += c
BINARIES  += keep
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS clean

test ! -e sub/bin/keep
test ! -e sub/bin/old
