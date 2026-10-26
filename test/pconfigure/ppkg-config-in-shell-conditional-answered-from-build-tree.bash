#include "harness_start.bash"

# A Configfile asks whether a package exists before asking for its
# flags, which is what an 'if' in a backtick is for.  Both commands
# inside the 'if' have to be answered out of the build tree, since the
# package is one a subproject provides, and the backtick has to stay
# the shell the person wrote.  The build tree's directories used to be
# put in front of the command as a "PKG_CONFIG_PATH=... " assignment;
# in front of an 'if' that made the shell read 'if' as the name of a
# program, and the whole command was a syntax error.
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
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >src/test.c <<EOF
#include <sub.h>
#include <stdio.h>
int main(void) { printf("%d\n", sub()); return 0; }
EOF

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`if ppkg-config sub --exists; then ppkg-config sub --cflags; fi\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

here="$(pwd -P)"
grep -q -- "-I$here/sub/include" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
