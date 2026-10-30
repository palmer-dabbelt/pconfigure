test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A BINARIES name with a directory in it is a program one level down
# in bin/, and that changes how far it is from lib/: the copy in the
# build tree has to find its library at $ORIGIN/../../lib rather than
# $ORIGIN/../lib, and the installed copy at $PREFIX/lib.  The build-tree
# copy is checked by running it, which is the only check of a RUNPATH
# that means anything.  The installed copy can't be run, since DESTDIR
# puts its library somewhere other than where its RUNPATH says, so for
# that one the RUNPATH itself is read back.
mkdir -p src test/tools/run
echo 'int f(void) { return 0; }' > src/f.c
echo 'int f(void); int main(void) { return f(); }' > src/run.c
echo '$PTEST_BINARY' > test/tools/run/t.bash

cat >Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash

LIBRARIES += libf.so
SOURCES   += f.c

BINARIES  += tools/run
DEPLIBS   += f
SOURCES   += run.c
TESTSRC   += t.bash
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/tools/run

# Run from somewhere else, too, since a RUNPATH relative to the
# current directory would pass from here and from nowhere else.
(cd / && $tempdir/bin/tools/run)

make $MAKE_ARGS check
test "$(tar -xOf check/tools/run/t.bash ptest__return)" = 0

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -x dest/usr/local/bin/tools/run
test -f dest/usr/local/lib/libf.so
readelf -d dest/usr/local/bin/tools/run > installed.dyn
cat installed.dyn
grep -q 'R.*PATH.*/usr/local/lib' installed.dyn
if grep -q 'ORIGIN' installed.dyn
then
    exit 1
fi
