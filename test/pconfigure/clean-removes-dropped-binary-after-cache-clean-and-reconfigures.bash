#include "harness_start.bash"

# What a dropped target left behind is remembered in the object
# directory, since the Makefile written after the line went has no
# other way to know the name.  That record has to outlive the things
# that happen between dropping a line and getting round to a clean:
# a "make cache-clean", which throws away whatever in the object
# directory the Makefile doesn't name, and more configures, each of
# which writes the record again from a Configfile that no longer
# says "old" anywhere.

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

cat >Configfile <<'EOC'
LANGUAGES += c
BINARIES  += keep
SOURCES   += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS cache-clean
$PTEST_BINARY $PCONFIGURE_ARGS
$PTEST_BINARY $PCONFIGURE_ARGS
test -x bin/old

make $MAKE_ARGS clean
test ! -e bin/keep
test ! -e bin/old

# And once it is gone the record lets go of it, so that a clean of a
# tree that has since been rebuilt doesn't fail or go looking for it.
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS clean
test ! -e bin/keep
