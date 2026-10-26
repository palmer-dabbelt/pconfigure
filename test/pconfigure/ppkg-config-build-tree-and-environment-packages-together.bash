#include "harness_start.bash"

# The build tree's .pc directories go in front of PKG_CONFIG_PATH for a
# backtick, and the caller's own PKG_CONFIG_PATH stays behind them: a
# project that links one package a subproject provides and another the
# person running pconfigure pointed PKG_CONFIG_PATH at gets both, in
# one configure.
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

mkdir -p elsewhere/include elsewhere/pc
cat >elsewhere/include/other.h <<'EOF'
#define OTHER 4
EOF
cat >elsewhere/pc/other.pc <<EOF
Name: other
Description: a package from the environment
Version: 1.0
Cflags: -I$(pwd)/elsewhere/include
EOF
export PKG_CONFIG_PATH="$(pwd)/elsewhere/pc"

cat >Configfile <<EOF
SUBPROJECTS += sub

LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += \`ppkg-config sub --cflags\`
COMPILEOPTS += \`ppkg-config other --cflags\`
LINKOPTS    += \`ppkg-config sub --libs\`
SOURCES     += test.c
EOF

cat >src/test.c <<'EOF'
#include <sub.h>
#include <other.h>
#include <stdio.h>
int main(void) { printf("%d\n", sub() + OTHER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/test)" = "11"

exit 0
