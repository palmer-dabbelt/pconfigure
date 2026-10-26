#include "harness_start.bash"

# "#elifndef NAME", C23's "#elif !defined(NAME)".  Nothing defines
# NO_EXTRA here, so the compiler takes that branch and reads extra.h;
# the scan didn't recognise the directive, judged the line by the
# "#ifdef USE_A" above it, and left extra.c out of the link.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
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
#ifdef USE_A
static int extra(void) { return 1; }
#elifndef NO_EXTRA
#include "extra.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
