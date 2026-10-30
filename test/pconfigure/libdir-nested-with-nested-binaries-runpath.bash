test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A LIBDIR two levels deep, a library in it that links another, and a
# program and a helper one level down in bin/ and libexec/.  A
# build-tree RUNPATH is the climb from its own file's directory back to
# the top of the tree and down into the LIBDIR, so the nesting has to be
# counted on both ends; the installed copies carry the prefix's
# matching directory instead.  The programs link only libg.so, so
# libf.so can only be found through libg.so's own RUNPATH: that is the
# library end of the climb, and it is also checked directly.  Both
# build-tree programs are run from somewhere other than the project,
# since a RUNPATH that only resolved relative to the working directory
# would pass from here.
mkdir -p src
echo 'int f(void) { return 0; }' > src/f.c
echo 'int f(void); int g(void) { return f(); }' > src/g.c
echo 'int g(void); int main(void) { return g(); }' > src/main.c

cat >Configfile <<EOF
LANGUAGES += c
LIBDIR     = out/lib

LIBRARIES += libf.so
SOURCES   += f.c

LIBRARIES += libg.so
DEPLIBS   += f
SOURCES   += g.c

BINARIES  += tools/run
DEPLIBS   += g
SOURCES   += main.c

LIBEXECS  += x/y
DEPLIBS   += g
SOURCES   += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f out/lib/libf.so
test -f out/lib/libg.so
readelf -d out/lib/libg.so > built.dyn
cat built.dyn
grep -q 'R.*PATH.*\[\$ORIGIN/\.\./\.\./out/lib\]' built.dyn
(cd / && $tempdir/bin/tools/run)
(cd / && $tempdir/libexec/x/y)

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -f dest/usr/local/out/lib/libf.so
test -f dest/usr/local/out/lib/libg.so
for f in bin/tools/run libexec/x/y out/lib/libg.so
do
    readelf -d dest/usr/local/$f > installed.dyn
    cat installed.dyn
    grep -q 'R.*PATH.*\[/usr/local/out/lib\]' installed.dyn
done

# Nothing went to the default LIBDIR, and uninstall takes it all back.
test ! -e dest/usr/local/lib
make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
find dest -type f > left
cat left
test ! -s left
