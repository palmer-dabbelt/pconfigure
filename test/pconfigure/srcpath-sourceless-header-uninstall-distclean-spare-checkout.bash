#include "harness_start.bash"

# The install rule of a HEADERS with nothing under it reads the header
# out of the checkout when there's a "--srcpath", and the rules that
# undo a build mustn't follow it there.  "make uninstall" takes the
# header out of the prefix and nothing else, and "make distclean"
# removes what the build wrote: the header in checkout/include was
# written by somebody, the build can't write it again, and a checkout
# is allowed to be shared by other builds or to be read-only.
mkdir -p checkout/src checkout/include build
cat >checkout/include/x.h <<'EOF2'
#define X_VALUE 0
EOF2
cat >checkout/src/main.c <<'EOF2'
#include <x.h>
int main(void) { return X_VALUE; }
EOF2

cat >checkout/Configfile <<'EOF2'
LANGUAGES += c
BINARIES  += main
SOURCES   += main.c
HEADERS   += x.h
EOF2

# What the checkout holds before anything is built, so that anything
# the build, the install or the cleaning changed out there shows up as
# a difference.
before="$(cd checkout && find . -print | sort && cat include/x.h)"

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../checkout
make $MAKE_ARGS
make $MAKE_ARGS DESTDIR=$tempdir/dest install
test -f $tempdir/dest/usr/local/include/x.h

make $MAKE_ARGS DESTDIR=$tempdir/dest uninstall
test ! -e $tempdir/dest/usr/local/include/x.h
test ! -e $tempdir/dest/usr/local/bin/main

make $MAKE_ARGS distclean
test ! -e Makefile
test ! -e bin
test ! -e obj
cd ..

after="$(cd checkout && find . -print | sort && cat include/x.h)"
diff -u <(echo "$before") <(echo "$after")

exit 0
