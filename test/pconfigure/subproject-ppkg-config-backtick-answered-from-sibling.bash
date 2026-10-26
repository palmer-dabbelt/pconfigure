#include "harness_start.bash"

# A subproject's backticks run in the subproject's own directory, but
# the .pc files this build writes are in the build tree, named
# relative to the top of it.  Handed to ppkg-config as they were, they
# would name a directory under the subproject that doesn't exist, and
# a package a sibling subproject provides would be reported missing.
mkdir -p sub/src app/src

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

echo 'int sub(void);' >sub/src/sub.h
echo 'int sub(void) { return 7; }' >sub/src/sub.c

cat >app/src/test.c <<EOF
#include <sub.h>
#include <stdio.h>
int main(void) { printf("%d\n", sub()); return 0; }
EOF

cat >app/Configfile <<EOF
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub
SUBPROJECTS += app
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

# The header is found only through the -I the backtick printed, so
# compiling the consumer at all says the package was found.  The
# library is a sibling's, which the consumer's RPATH doesn't cover, so
# running it is told where that is.
make $MAKE_ARGS
test "$(LD_LIBRARY_PATH="$(pwd)/sub/lib" ./app/bin/test)" = "7"

exit 0
