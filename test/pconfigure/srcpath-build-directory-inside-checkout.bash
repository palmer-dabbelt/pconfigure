#include "harness_start.bash"

# The common out-of-tree layout puts the build directory inside the
# checkout: "mkdir build && cd build && pconfigure --srcpath ..".  The
# build's own Makefile, obj/ and bin/ are then under the source tree,
# and they must stay out of what is read as sources; an edit to the
# Configfile up there reconfigures under AUTORECONFIGURE, and a header
# edited in the checkout recompiles.
mkdir -p src include test/hello build
cat >src/hello.c <<'EOF2'
#include "h.h"
int main(void) { return X; }
EOF2
echo '#define X 0' > include/h.h
printf '#!/bin/bash\nexit 0\n' > test/hello/t.bash
cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES += c
LANGUAGES += bash
BINARIES  += hello
SOURCES   += hello.c
TESTSRC   += t.bash
EOF2

cd build
$PTEST_BINARY --srcpath ..
make
./bin/hello
make check
test -e check/hello/t.bash
test ! -e ../Makefile
test ! -e ../bin
test ! -e ../obj
test ! -e ../check

echo '#define X 3' > ../include/h.h
make
status=0
./bin/hello || status=$?
test "$status" -eq 3

echo 'BINARIES += second' >> ../Configfile
echo 'SOURCES += hello.c' >> ../Configfile
make
test -x bin/second
test ! -e ../Makefile
