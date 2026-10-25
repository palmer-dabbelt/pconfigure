#include "harness_start.bash"

# With "--srcpath" the checkout is somewhere else and the build
# directory starts out empty, so a HEADERS with nothing under it --
# "copy $HDRDIR/x.h into the prefix" -- has to read the header out of
# the checkout's include directory, the same place a compile that
# includes it finds it.  Its install rule used to name "include/x.h"
# in the build directory instead, which nothing builds: "make" passed,
# because nothing in "all" needs the header, and then "make install"
# stopped on "No rule to make target 'include/x.h'".
mkdir -p checkout/src checkout/include build
echo 'int x_value(void);' > checkout/include/x.h
cat >checkout/src/main.c <<'EOF2'
#include <x.h>
int x_value(void) { return 0; }
int main(void) { return x_value(); }
EOF2

cat >checkout/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
HEADERS   += x.h
EOF2

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout
cat Makefile
make $MAKE_ARGS
./bin/main

make $MAKE_ARGS DESTDIR=$tempdir/dest install
cd ..
diff -u checkout/include/x.h dest/usr/local/include/x.h
test -x dest/usr/local/bin/main

# Nothing appeared in the checkout on the way, and in particular the
# build didn't make itself an include directory to copy from.
test ! -e checkout/bin
test ! -e checkout/obj
test ! -e build/include

exit 0
