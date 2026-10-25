#include "harness_start.bash"

# "make uninstall" on a staging directory that never had anything
# installed into it -- or had it removed by hand -- has nothing to take
# out, and that is success rather than an error: every rule is an
# "rm -f".  It mustn't build anything to find that out, either: an
# uninstall on a tree nobody has built yet leaves it unbuilt.
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
echo 'echo hi' > src/script.bash
echo 'int f(void);' > include/f.h
printf 'prefix=@@pconfigure_prefix@@\nName: f\nDescription: f\nVersion: 1\n' > src/f.pc

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash
LANGUAGES += pkgconfig

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

LIBRARIES += pkgconfig/f.pc
SOURCES   += f.pc

HEADERS   += f.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/never uninstall
test ! -e never
test ! -e bin
test ! -e lib

# And twice over after a real install.
make $MAKE_ARGS DESTDIR=$tempdir/dest install
test "$(find dest -type f | wc -l)" -eq 4
make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
test -z "$(find dest -type f)"
