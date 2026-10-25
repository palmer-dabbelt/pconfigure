#include "harness_start.bash"

# The LINKOPTS spelling of a circular pair of archives: "-la -lb -la"
# on one line.  Naming an archive a second time is how a link line
# says "look in it again", and GNU ld needs it here, because b1() in
# libb pulls in a2() from liba after liba has already been read.  The
# duplicate filter on link options drops the second "-la" anyway.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

LIBRARIES += liba.a
SOURCES   += a1.c
SOURCES   += a2.c

LIBRARIES += libb.a
SOURCES   += b1.c

BINARIES  += app
LINKOPTS  += -la -lb -la
SOURCES   += main.c
EOF

echo 'int b1(void); int a1(void) { return b1() + 1; }' >src/a1.c
echo 'int a2(void) { return 2; }' >src/a2.c
echo 'int a2(void); int b1(void) { return a2() + 10; }' >src/b1.c

cat >src/main.c <<'EOF'
#include <stdio.h>
int a1(void);
int main(void) { printf("%d\n", a1()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q -- '-la -lb -la' Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "13"
