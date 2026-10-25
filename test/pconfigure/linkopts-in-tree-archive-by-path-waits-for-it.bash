#include "harness_start.bash"

# An in-tree archive can be put on a link line by its path rather than
# by "-l": "LINKOPTS += lib/libfoo.a", which is how an archive gets
# linked whole or ahead of a shared library of the same name.  The
# link rule still waits for it, so asking make for the program alone
# builds the archive first.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
LINKOPTS  += lib/libfoo.a
SOURCES   += main.c

LIBRARIES += libfoo.a
SOURCES   += foo.c
EOF

echo 'int foo(void) { return 12; }' >src/foo.c

cat >src/main.c <<'EOF'
#include <stdio.h>
int foo(void);
int main(void) { printf("%d\n", foo()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/bin/app/[^ ]*/local:' Makefile | tr ' ' '\n' | grep -qx lib/libfoo.a

make $MAKE_ARGS bin/app
test "$(./bin/app)" = "12"
