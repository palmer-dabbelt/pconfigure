#include "harness_start.bash"

# Two static archives that need each other: a1() in liba calls b1() in
# libb, and b1() calls a2(), which is back in liba.  A linker reads an
# archive once, taking only the members it needs right then, so the
# way to link this is to name liba again after libb -- "-la -lb -la"
# -- and DEPLIBS written three times says exactly that.  The link-line
# filter that drops repeated "-l" flags (written for ld64's duplicate
# warning) keeps only the first "-la", and a2() is then undefined.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
DEPLIBS   += a
DEPLIBS   += b
DEPLIBS   += a
SOURCES   += main.c

LIBRARIES += liba.a
SOURCES   += a1.c
SOURCES   += a2.c

LIBRARIES += libb.a
SOURCES   += b1.c
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

# The repeat survives onto the link line, after libb.
grep -q -- '-la -lb -la' Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "13"
