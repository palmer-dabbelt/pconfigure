#include "harness_start.bash"

# A LIBDIR goes onto the link line twice over: as the "$ORIGIN/../LIBDIR"
# rpath the tree's copy of a program finds its libraries with, and as
# the "$PREFIX/LIBDIR" one the installed copy does.  Both were written
# as "-Wl,-rpath,...", and the compiler driver splits a "-Wl," at
# every comma, so "LIBDIR = lib,v2" -- checked for leaving the project
# and for the shell's metacharacters, and a comma is neither -- failed
# every link of the program on "cannot find v2".  The directory is a
# perfectly good one, so both rpaths have to reach the linker whole:
# the program runs from the tree and from where it was installed to.
mkdir -p src
echo 'int f(void) { return 3; }' > src/f.c
echo 'int f(void); int main(void) { return f(); }' > src/main.c

cat >Configfile <<'EOF2'
LANGUAGES += c
LIBDIR     = lib,v2

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += main
DEPLIBS   += f
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS
set +e
bin/main
ret="$?"
set -e
test "$ret" == 3

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -f dest/usr/local/lib,v2/libf.so
readelf -d dest/usr/local/bin/main | grep -F '[/usr/local/lib,v2]'
