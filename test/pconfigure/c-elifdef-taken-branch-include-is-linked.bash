#include "harness_start.bash"

# "#elifdef NAME" is C23's spelling of "#elif defined(NAME)", and gcc
# and clang take it in every language mode.  The scan only knew
# "#elif": an "#elifdef" line was nothing to it, so the lines after it
# went by the "#ifdef USE_A" at the top of the chain, which is off.
# With USE_B given the compiler reads extra.h, the scan skipped it,
# and the link failed for want of extra.c.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DUSE_B
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
#elifdef USE_B
#include "extra.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
