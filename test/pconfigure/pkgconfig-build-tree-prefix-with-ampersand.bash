#include "harness_start.bash"

# The pkg-config file a subproject builds for its consumers is written
# twice: once for the install, and once describing the build tree,
# which is the copy a "ppkg-config" backtick in the project above is
# answered out of.  That second copy gets the absolute path of the
# checkout as its prefix, through a sed substitution -- and in a sed
# replacement an '&' means "the text that matched".  Pasted in as it
# was, a checkout under "R&D" came out with a prefix of
# ".../R@@pconfigure_prefix@@D/sub", the consumer was handed an -I and
# an -L that named nothing, and the build failed to find the
# subproject's header.  pconfigure itself has no trouble with the
# directory: nothing else it writes names it.
mkdir "R&D"
cd "R&D"

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
int main(void) { printf("%d\\n", sub()); return 0; }
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

here="$(pwd -P)"
grep -q "^prefix=$here/sub$" sub/obj/pkgconfig/sub.pc
if grep -q "@@pconfigure_prefix@@" sub/obj/pkgconfig/sub.pc
then
    exit 1
fi

# pkg-config hands the "-L" back as ".../R\&D/sub/lib", which is the
# shell's spelling of the directory rather than the directory, and
# it's the directory that has to be recognized as part of this build
# for the binary to get an rpath that finds the subproject's library.
make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
