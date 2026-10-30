#include "harness_start.bash"

# "-include" looks for its file in the directory the compiler was run
# from first and then along the include path, the way a '#include
# "..."' does.  Here there is no config.h at the top of the tree, so
# the compiler reads the one in "inc", and that is the one whose edit
# has to rebuild the program.
#
# AUTORECONFIGURE = true: pconfigure reads the options under false
# and pdeps does under true.

mkdir -p src inc

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -I inc -include config.h
SOURCES     += main.c
EOF

cat >inc/config.h <<'EOF'
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

cat >inc/config.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./bin/app)" = "2"
