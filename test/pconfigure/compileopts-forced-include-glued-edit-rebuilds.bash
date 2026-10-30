#include "harness_start.bash"

# gcc and clang both take the file "-include" names stuck on to the
# flag as well as in the word after it, the same as "-I" takes its
# directory.  Glued on, it is the same file read ahead of the source,
# and editing it has to rebuild what it went into all the same.
#
# AUTORECONFIGURE = false: pconfigure reads the options under false
# and pdeps does under true.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = false

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -includesrc/config.h
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
