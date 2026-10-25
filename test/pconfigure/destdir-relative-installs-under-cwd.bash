#include "harness_start.bash"

# DESTDIR doesn't have to be absolute.  A relative one is taken from
# the directory make runs in, like any other path in the recipes, and
# "make uninstall" with the same relative DESTDIR takes it all back out.
mkdir -p src include
echo 'int f(void) { return 0; }' > src/f.c
echo 'int main(void) { return 0; }' > src/main.c
echo 'echo hi' > src/script.bash
echo 'int f(void);' > include/f.h
printf 'prefix=@@pconfigure_prefix@@\nName: f\nDescription: f\nVersion: 1\n' > src/f.pc

cat >Configfile <<'EOF2'
LANGUAGES += c
LANGUAGES += bash
LANGUAGES += pkgconfig

LIBRARIES += libf.so
SOURCES   += f.c

LIBRARIES += pkgconfig/f.pc
SOURCES   += f.pc

BINARIES  += main
SOURCES   += main.c

BINARIES  += script
SOURCES   += script.bash

HEADERS   += f.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS DESTDIR=stage install

find stage -type f | sort > installed
cat installed
cat >expected <<'EOF2'
stage/usr/local/bin/main
stage/usr/local/bin/script
stage/usr/local/include/f.h
stage/usr/local/lib/libf.so
stage/usr/local/lib/pkgconfig/f.pc
EOF2
diff -u expected installed

# The staged .pc still describes the real prefix, not the stage.
grep -q '^prefix=/usr/local$' stage/usr/local/lib/pkgconfig/f.pc

make $MAKE_ARGS DESTDIR=stage uninstall
test -z "$(find stage -type f)"
