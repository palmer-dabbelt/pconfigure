#include "harness_start.bash"

# The same climb out of the project under AUTORECONFIGURE, where the
# scan runs inside pdeps while make is reading the Makefile.  pdeps has
# the same arithmetic for ".." as pconfigure, so the build stopped on a
# crashed pdeps rather than on anything the project got wrong.

mkdir -p proj/src shared
cd proj

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >../shared/shared.h <<'EOF'
#define SHARED 3
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "../../shared/shared.h"
int main(void) { printf("%d\n", SHARED); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "3"
