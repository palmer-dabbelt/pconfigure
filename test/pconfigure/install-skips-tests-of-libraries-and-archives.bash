#include "harness_start.bash"

# A compiled TESTSRC under a library is linked into a program of its
# own to be run, and a TESTSRC under a static archive the same, but
# neither program is something the package ships.  "make install"
# puts the libraries under the prefix and nothing of the tests: no
# test binary under the prefix and no check result in the tree.  The
# binaries-only case is install-skips-test-only-targets.bash; a test
# of a library is linked differently, against the library being
# tested, so it gets here by a different path.
mkdir -p src test/libf.so test/libg.a
echo 'int f(void) { return 0; }' > src/f.c
echo 'int g(void) { return 0; }' > src/g.c
echo 'int main(void) { return 0; }' > test/libf.so/f-works.c
echo 'int main(void) { return 0; }' > test/libg.a/g-works.c

cat >Configfile <<'EOF2'
LANGUAGES += c

LIBRARIES += libf.so
SOURCES   += f.c
TESTSRC   += f-works.c

LIBRARIES += libg.a
SOURCES   += g.c
TESTSRC   += g-works.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install

find dest -type f | sort > installed
cat installed
printf '%s\n' dest/usr/local/lib/libf.so dest/usr/local/lib/libg.a > expected
diff -u expected installed
test ! -e check

# The tests still pass, and running them installs nothing more.
make $MAKE_ARGS check
test "$(tar -xOf check/libf.so/f-works.c ptest__return)" = "0"
test "$(tar -xOf check/libg.a/g-works.c ptest__return)" = "0"
find dest -type f | sort > installed
diff -u expected installed
