#include "harness_start.bash"

# A shared library that DEPLIBS another one is linked twice, like a
# program: the copy in lib/ finds its neighbour relative to itself,
# and the installed copy is told the prefix's lib directory -- and not
# the build tree's, which won't be there on the machine it's installed
# on.  Checked by running an installed program, from a directory that
# isn't the tree, through both libraries.
mkdir -p src
echo 'int inner(void) { return 7; }' > src/inner.c
echo 'int inner(void); int outer(void) { return inner() - 7; }' > src/outer.c
echo 'int outer(void); int main(void) { return outer(); }' > src/main.c

cat >Configfile <<EOF2
PREFIX     = $tempdir/opt/thing
LANGUAGES += c

LIBRARIES += libinner.so
SOURCES   += inner.c

LIBRARIES += libouter.so
DEPLIBS   += inner
SOURCES   += outer.c

BINARIES  += main
DEPLIBS   += outer
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/main
make $MAKE_ARGS install

if test "$(uname -s)" != "Darwin"
then
    readelf -d opt/thing/lib/libouter.so > outer.dyn
    cat outer.dyn
    grep -q "R.*PATH.*\[$tempdir/opt/thing/lib\]" outer.dyn
    if grep -q "ORIGIN" outer.dyn
    then
        exit 1
    fi
fi

# With the build tree's libraries out of the way, the installed ones
# are the only ones there are to find.
mv lib lib.moved
(cd / && $tempdir/opt/thing/bin/main)
