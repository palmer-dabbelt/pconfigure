#include "harness_start.bash"

# "--ppkg-config <path>" swaps the given path in for the word
# "ppkg-config" inside a backtick, as text, and the command is then
# handed to a shell.  The path used to go in bare, so a ppkg-config
# kept under a directory with a space in it -- "/opt/my tools/bin", or
# a vendored checkout under somebody's "My Projects" -- ran "/opt/my"
# with "tools/bin/ppkg-config" as its first argument: "No such file or
# directory", a wait status, and a consumer configured without the
# subproject's flags.  The same path given to any other
# --<tool> option is one word, because it was one word on the
# command line.
mkdir -p src sub/src "my tools"
cp "$(dirname "$PTEST_BINARY")/ppkg-config" "my tools/ppkg-config"
tool="$(pwd)/my tools/ppkg-config"

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
LANGUAGES += pkgconfig

LIBRARIES += libsub.so
SOURCES   += sub.c

LIBRARIES += pkgconfig/sub.pc
SOURCES   += sub.pc
EOF

cat >sub/src/sub.pc <<EOF
prefix=@@pconfigure_prefix@@
libdir=\${prefix}/@@pconfigure_libdir@@

Name: sub
Description: a subproject
Version: 1.0
Libs: -L\${libdir} -lsub
Cflags: -DSUB_ANSWER=7
EOF

cat >sub/src/sub.c <<EOF
int sub(void) { return 7; }
EOF

cat >src/test.c <<EOF
#include <stdio.h>
int sub(void);
int main(void) { printf("%d\n", sub() + SUB_ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS --ppkg-config "$tool" 2>stderr
cat stderr
cat Makefile

if grep -q "No such file" stderr
then
    exit 1
fi
grep -q -- "-DSUB_ANSWER=7" Makefile

make $MAKE_ARGS
test "$(./bin/test)" = "14"

exit 0
