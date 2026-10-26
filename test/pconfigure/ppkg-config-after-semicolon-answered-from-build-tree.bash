#include "harness_start.bash"

# Two questions in one backtick, separated by a ';': the first one is
# about a package the machine might have, the second about one this
# build provides in a subproject.  Every command in the backtick has to
# be answered out of the build tree, not just the first, so the second
# question has to find sub.pc there.  The build tree's directories used
# to be put in front of the command as a "PKG_CONFIG_PATH=... "
# assignment, which reached only the first simple command on the line,
# so the second was asked about the machine alone and configure
# stopped.
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
COMPILEOPTS += \`ppkg-config --optional not-on-this-machine --cflags; ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

here="$(pwd -P)"
grep -q -- "-I$here/sub/include" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
