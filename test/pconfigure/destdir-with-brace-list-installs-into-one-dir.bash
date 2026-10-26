#include "harness_start.bash"

# make runs recipes under bash, and bash expands "st{a,b}" into two
# words.  A DESTDIR spelled that way -- a perfectly good directory
# name -- turned every "mkdir -p $(DESTDIR)/..." into two directories,
# "sta" and "stb", and every copy into a "cp" with one argument too
# many, so "make install" failed after scattering empty directory
# trees that nobody named.  Either the install lands in the directory
# DESTDIR names, or it is refused in words naming DESTDIR, and either
# way "sta" and "stb" never appear.
mkdir -p src include
echo 'int main(void) { return 0; }' > src/main.c
echo 'int f(void);' > include/main.h

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c

HEADERS   += main.h
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

destdir="$tempdir/st{a,b}"
if make $MAKE_ARGS DESTDIR="$destdir" install > install.out 2>&1
then
    cat install.out
    test -x "$destdir/usr/local/bin/main"
    test -f "$destdir/usr/local/include/main.h"
else
    cat install.out
    grep -F "DESTDIR=\"$destdir\"" install.out
fi

ls -a
test ! -e "$tempdir/sta"
test ! -e "$tempdir/stb"
