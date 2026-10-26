#include "harness_start.bash"

# A shared library is linked with its own name as its soname, which
# went on the link line as "-Wl,-soname,NAME" -- and the compiler
# driver splits a "-Wl," at every comma, so a library called
# "libf,v2.so" gave the linker a soname of "libf" and an input file
# "v2.so" it couldn't find.  The name means nothing special to make or
# the shell, which is all the checks on a LIBRARIES name ask about, so
# it was accepted and the failure came out of the link with no
# Configfile line.  Nothing is wrong with the name: the library builds
# with all of it as its soname, and a program linked against it
# records that whole name and runs.
mkdir -p src
echo 'int f(void) { return 3; }' > src/f.c
echo 'int f(void); int main(void) { return f(); }' > src/main.c

cat >Configfile <<'EOF2'
LANGUAGES += c
LIBRARIES += libf,v2.so
SOURCES   += f.c

BINARIES  += main
LINKOPTS  += -l:libf,v2.so
SOURCES   += main.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS
readelf -d lib/libf,v2.so | grep -F '[libf,v2.so]'
readelf -d bin/main | grep -F 'NEEDED' | grep -F '[libf,v2.so]'
set +e
bin/main
ret="$?"
set -e
test "$ret" == 3

make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -f dest/usr/local/lib/libf,v2.so
