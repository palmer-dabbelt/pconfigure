#include "harness_start.bash"

# A header read through "-include" is read like any other, so what it
# includes is read too.  The version number here lives one header
# further down, found through the include path, and editing it has
# to rebuild the program just as it would if the source had included
# it itself.
#
# AUTORECONFIGURE = true: pconfigure reads the options under false
# and pdeps does under true.

mkdir -p src inc

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Iinc -include src/config.h
SOURCES     += main.c
EOF

cat >src/config.h <<'EOF'
#include "version.h"
EOF

cat >inc/version.h <<'EOF'
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

cat >inc/version.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./bin/app)" = "2"
