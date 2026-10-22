#include "harness_start.bash"

# A library this project builds has to win over one of the same name
# in a directory a LINKOPTS adds.  That directory is usually a
# pkg-config answer like "-L/usr/local/lib", which is exactly where an
# older "make install" of this same project left its old libone.so --
# and a link that reaches that one first links the program against
# yesterday's library.  Here the stale copy lacks two(), so linking
# against it fails outright; the new one has it.
#
# The stale copy is outside the project and the path to it absolute,
# the way an installed library's would be.

mkdir -p stale proj/src

cat >stale/one.c <<'EOF'
int one(void) { return 99; }
EOF
${CC:-cc} -shared -fPIC -o stale/libone.so stale/one.c

cd proj

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

BINARIES  += app
LINKOPTS  += -L$(cd ../stale && pwd)
DEPLIBS   += one
SOURCES   += main.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
int two(void) { return 2; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int one(void);
int two(void);
int main(void) { printf("%d\n", one() + two()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "3"
