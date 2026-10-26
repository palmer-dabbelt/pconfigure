#include "harness_start.bash"

# DESTDIR is where a package is staged, not where it will live, so
# nothing installed may remember it: the .pc that lands under
# $DESTDIR$PREFIX/lib/pkgconfig says the PREFIX and nowhere mentions
# the staging directory.  A .pc that carried the staging directory
# would send every consumer of the finished package looking in a
# directory that was deleted once the package was built.  The .pc is
# made by running its template through sed, so the install is also
# checked for leaving no scratch file behind, neither under the stage
# nor anywhere the build tree keeps its .pc files.  (The tree as a
# whole does change: the shared library's installed link is built in
# obj/ on purpose.)
mkdir -p src
cat > src/thing.pc <<'EOF2'
prefix=@@pconfigure_prefix@@
libdir=${prefix}/@@pconfigure_libdir@@
includedir=${prefix}/@@pconfigure_hdrdir@@

Name: thing
Description: a thing
Version: 1.0
Libs: -L${libdir} -lthing
Cflags: -I${includedir}
EOF2
echo 'int thing(void) { return 0; }' > src/thing.c

cat >Configfile <<'EOF2'
PREFIX     = /opt/thing
LANGUAGES += c
LANGUAGES += pkgconfig

LIBRARIES += libthing.so
SOURCES   += thing.c

LIBRARIES += pkgconfig/thing.pc
SOURCES   += thing.pc
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

before="$(find . | grep -e pkgconfig -e thing.pc | sort)"
make $MAKE_ARGS DESTDIR=$tempdir/stage install
after="$(find . -path ./stage -prune -o -print | grep -e pkgconfig -e thing.pc | sort)"
test -n "$before"
test "$before" == "$after"

staged=stage/opt/thing/lib/pkgconfig/thing.pc
cat $staged
grep -qx 'prefix=/opt/thing' $staged
grep -qx 'libdir=${prefix}/lib' $staged
grep -qx 'includedir=${prefix}/include' $staged
if grep -F "$tempdir" $staged
then
    exit 1
fi
if grep -F stage $staged
then
    exit 1
fi

# Asked through pkg-config itself, the staged file answers for the
# prefix.
if command -v pkg-config > /dev/null
then
    test "$(PKG_CONFIG_PATH=stage/opt/thing/lib/pkgconfig pkg-config --variable=prefix thing)" == "/opt/thing"
    test "$(PKG_CONFIG_PATH=stage/opt/thing/lib/pkgconfig pkg-config --libs thing)" == "-L/opt/thing/lib -lthing"
fi

# The stage holds exactly the two installed files.
find stage -type f | sort > staged
cat staged
printf '%s\n' stage/opt/thing/lib/libthing.so $staged > expected
diff -u expected staged
