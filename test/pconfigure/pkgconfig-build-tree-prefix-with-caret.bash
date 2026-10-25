#include "harness_start.bash"

# The build-tree copy of a subproject's .pc gets its prefix out of a
# sed substitution that uses '^' as its delimiter, with the absolute
# checkout path between two of them.  A '^' in that path (legal in a
# directory name, and in a few people's naming schemes) used to end
# the replacement early: sed refused the expression with "unknown
# option to 's'", pconfigure carried on with no build-tree .pc, the
# "ppkg-config sub" backticks failed, and the consumer was configured
# without the subproject's flags at all.
mkdir "v1^2"
cd "v1^2"

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

$PTEST_BINARY $PCONFIGURE_ARGS 2>stderr
cat stderr

# Nothing pconfigure ran on the way should have failed, either.
if grep -q "unknown option to" stderr
then
    exit 1
fi

test -f sub/obj/pkgconfig/sub.pc
here="$(pwd -P)"
grep -qF "prefix=$here/sub" sub/obj/pkgconfig/sub.pc

make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
