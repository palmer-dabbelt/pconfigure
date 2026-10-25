#include "harness_start.bash"

# A checkout whose path has a space in it builds -- that much is
# tested elsewhere -- and so does one where a subproject exports its
# flags through pkg-config.  The build-tree .pc used to say
#
#     prefix=/home/me/my checkout/sub
#
# with the space bare, which pkg-config read as the end of one word
# and the start of the next, so the consumer was handed
# "-I/home/me/my" and "checkout/sub/include" and the subproject's
# header was not found.
#
# pkg-config has a spelling for this -- a backslash before the space
# -- and it's the .pc's writer who knows the path is one word.  What
# comes back is "-I/home/me/my\ checkout/sub/include", which the
# compile line has to keep as one word, and which the header search,
# the rpath and the link dependency all have to read as the directory
# it names.
mkdir "my checkout"
cd "my checkout"

mkdir -p src sub/src

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += h
LANGUAGES += pkgconfig

HEADERSRC += sub.h

LIBRARIES += libsub.so
SOURCES   += sub.c

LIBRARIES += pkgconfig/sub.pc
SOURCES   += sub.pc
EOF

cat >sub/src/sub.pc <<EOF
prefix=@@pconfigure_prefix@@
libdir=\${prefix}/@@pconfigure_libdir@@
includedir=\${prefix}/@@pconfigure_hdrdir@@

Name: sub
Description: a subproject
Version: 1.0
Libs: -L\${libdir} -lsub
Cflags: -I\${includedir}
EOF

cat >sub/src/sub.h <<EOF
int sub(void);
#define SUB_SCALE 1
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >src/test.c <<EOF
#include <sub.h>
#include <stdio.h>
int main(void) { printf("%d\\n", sub() * SUB_SCALE); return 0; }
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat sub/obj/pkgconfig/sub.pc
cat Makefile

here="$(pwd -P)"
grep -qxF "prefix=${here// /\\ }/sub" sub/obj/pkgconfig/sub.pc

# The header the subproject installs is a prerequisite of the object
# that includes it, named the way the subproject's own Makefile names
# it rather than through the checkout's absolute path: make has no
# quoting for a prerequisite, and would split that one at the space.
grep -q "^obj/src/test.c/[^:]*: src/test.c sub/include/sub.h$" Makefile
grep -q "^obj/bin/test/.*/local: sub/lib/libsub.so$" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "7"

# ... and being a prerequisite, an edit to it is noticed.
sleep 1
cat >sub/src/sub.h <<EOF
int sub(void);
#define SUB_SCALE 2
EOF
make $MAKE_ARGS
test "$(./bin/test)" = "14"

exit 0
