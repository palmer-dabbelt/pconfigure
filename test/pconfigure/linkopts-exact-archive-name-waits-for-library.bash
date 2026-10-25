#include "harness_start.bash"

# "-l:libfoo.a" is GNU ld's way of asking for one file by its exact
# name -- the static archive even where a shared library of the same
# name would win -- and it searches the "-L" directories the way
# "-lfoo" does.  That's still a "-l" naming an in-tree library, so the
# link has to wait for lib/libfoo.a: asking make for the program alone,
# the way a parallel build can reach it first, must build the archive
# before linking rather than fail to find it.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
LINKOPTS  += -l:libfoo.a
SOURCES   += main.c

LIBRARIES += libfoo.a
SOURCES   += foo.c
EOF

echo 'int foo(void) { return 9; }' >src/foo.c

cat >src/main.c <<'EOF'
#include <stdio.h>
int foo(void);
int main(void) { printf("%d\n", foo()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

make $MAKE_ARGS bin/app
test "$(./bin/app)" = "9"
