#include "harness_start.bash"

mkdir -p src sub/src

# The top level doesn't say where the subproject's headers and library
# are: it asks pkg-config, the way it would for any other dependency.
cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

cat >sub/Configfile <<EOF
LANGUAGES += c
LANGUAGES += bash
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

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat sub/Makefile

# pkg-config was answered out of the build tree rather than out of
# whatever happens to be installed on this machine, so the flags point
# at the subproject as it is right now.  "pwd -P" because pconfigure
# asks the kernel where it is, and on macOS that resolves the symlink
# that a temporary directory sits behind.
here="$(pwd -P)"
test -f sub/obj/pkgconfig/sub.pc
grep -q "^prefix=$here/sub$" sub/obj/pkgconfig/sub.pc

# ... and those flags are what the top level actually compiles and
# links with.
grep -q -- "-I$here/sub/include" Makefile
grep -q -- "-L$here/sub/lib" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "7"

# The library it links against is still a dependency, worked out from
# the "-lsub" that pkg-config handed back.
grep -q "^obj/bin/test/.*/local: sub/lib/libsub.so$" Makefile

# The installed .pc file still describes where things get installed to,
# which is not where they were built.
make $MAKE_ARGS D=$(pwd)/install DESTDIR=$(pwd)/install install
grep -q "^prefix=/usr/local$" install/usr/local/lib/pkgconfig/sub.pc

exit 0
