#include "harness_start.bash"

# The same string literal under AUTORECONFIGURE, where it is pdeps
# rather than pconfigure that reads the source.  The two share the
# scan, so the "/*" in the glob hid the include from the fragment
# just as it did from the Makefile, and extra.c was left out of the
# link.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
static const char *pattern = "logs/*.log";
#include "extra.h"
int main(void) { printf("%d %s\n", extra(), pattern); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "7 logs/*.log"
