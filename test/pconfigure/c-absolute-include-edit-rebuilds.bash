#include "harness_start.bash"

# A header named by an absolute path is a header like any other to the
# compiler, so editing it has to rebuild what read it.  The scan never
# found it -- it looked for the path under the includer's directory --
# so it wasn't a prerequisite of the object, and the edit left the
# program printing the old value.

mkdir -p src shared

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >shared/value.h <<'EOF'
#define VALUE 1
EOF

cat >src/main.c <<EOF
#include <stdio.h>
#include "$tempdir/shared/value.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 1
cat >shared/value.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
./bin/app
test "$(./bin/app)" = "2"
