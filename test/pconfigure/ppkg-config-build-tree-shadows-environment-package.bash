#include "harness_start.bash"

# A copy of the subproject's package is already installed somewhere the
# caller's PKG_CONFIG_PATH points -- an older release, with its headers
# somewhere else.  The build tree's copy has to win, so the project is
# compiled against the subproject it is about to link with rather than
# against whatever was installed before.
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

mkdir -p stale/include stale/pc
cat >stale/include/sub.h <<'EOF'
#error the installed copy of sub.h was used instead of the build tree
EOF
cat >stale/pc/sub.pc <<EOF
Name: sub
Description: an old installed copy
Version: 0.1
Cflags: -I$(pwd)/stale/include
Libs: -L$(pwd)/stale/lib -lsub
EOF
export PKG_CONFIG_PATH="$(pwd)/stale/pc"

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

# The stale copy's directories mustn't reach a compile or link line.
# Only its include and lib directories are looked for, not every
# mention of it: the caller's PKG_CONFIG_PATH may well be written into
# the Makefile for the backticks it re-runs, and that names stale/pc.
$PTEST_BINARY $PCONFIGURE_ARGS
if grep -qE "stale/(include|lib)" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/test)" = "7"

exit 0
