#include "harness_start.bash"

# "-imacros FILE" is "-include FILE" that keeps only the macros, which
# are the whole of what a header like this one is for.  The compiler
# reads it before every source all the same, so editing it has to
# rebuild what it went into.
#
# AUTORECONFIGURE = true: pconfigure reads the options under false
# and pdeps does under true.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -imacros src/config.h
SOURCES     += main.c
EOF

cat >src/config.h <<'EOF'
#define VALUE 1
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

find . -type f -exec touch -t 200001010000 {} +

cat >src/config.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./bin/app)" = "2"
