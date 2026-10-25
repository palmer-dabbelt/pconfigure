#include "harness_start.bash"

# "@@pconfigure_libdir@@" in a .pc template is the project's LIBDIR,
# relative to the prefix, in both copies pconfigure writes: the
# installed one (prefix is PREFIX) and the build-tree one (prefix is
# where the project is).  A LIBDIR other than the default moves the
# .pc itself too, since pkgconfig/x.pc is a LIBRARY like any other.
# A DESTDIR install has to carry the installed copy's answers, not the
# staging directory's: the staged file is going to be read from PREFIX.
mkdir -p src

cat >Configfile <<EOF
PREFIX    = /opt/somewhere
LIBDIR    = mylib
LANGUAGES += pkgconfig

LIBRARIES += pkgconfig/x.pc
SOURCES   += x.pc
EOF

cat >src/x.pc <<'EOF'
prefix=@@pconfigure_prefix@@
libdir=${prefix}/@@pconfigure_libdir@@
includedir=${prefix}/@@pconfigure_hdrdir@@
Name: x
Description: x
Version: 1
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

here="$(pwd -P)"
cat mylib/pkgconfig/x.pc obj/pkgconfig/x.pc
test ! -e lib/pkgconfig/x.pc

grep -q "^prefix=/opt/somewhere$" mylib/pkgconfig/x.pc
grep -q "^libdir=\${prefix}/mylib$" mylib/pkgconfig/x.pc
grep -q "^includedir=\${prefix}/include$" mylib/pkgconfig/x.pc

grep -q "^prefix=$here$" obj/pkgconfig/x.pc
grep -q "^libdir=\${prefix}/mylib$" obj/pkgconfig/x.pc

make $MAKE_ARGS DESTDIR="$(pwd)/stage" install
find stage -type f
grep -q "^prefix=/opt/somewhere$" stage/opt/somewhere/mylib/pkgconfig/x.pc
grep -q "^libdir=\${prefix}/mylib$" stage/opt/somewhere/mylib/pkgconfig/x.pc

exit 0
