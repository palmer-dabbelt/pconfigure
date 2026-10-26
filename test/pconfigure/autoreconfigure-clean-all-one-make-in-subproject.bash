#include "harness_start.bash"

# The copied-header case of "make clean all", with the header and the
# program that reads it down in a subproject.  The subproject's
# Makefile is one the parent includes, and its fragments are settled
# while the parent's makefiles are remade -- so it is the parent's
# Makefile that has to hand the goals out one make at a time, and the
# subproject's copy of that never gets a say.  Under -j2 as well as
# serially, since the goals running in the order given is the whole
# point and a parallel make is the one most likely to overlap them.

mkdir -p sub/src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
SUBPROJECTS     += sub
EOF2

cat >sub/Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES       += c
LANGUAGES       += h

HEADERSRC       += x.h

BINARIES        += hello
SOURCES         += hello.c
EOF2

echo '#define X 0' > sub/src/x.h
cat >sub/src/hello.c <<'EOF2'
#include <x.h>
int main(void) { return X; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS -j1
sub/bin/hello

make $MAKE_ARGS -j1 clean all
sub/bin/hello

make $MAKE_ARGS -j2 clean all
sub/bin/hello

exit 0
