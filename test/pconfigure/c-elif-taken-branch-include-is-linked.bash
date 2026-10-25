#include "harness_start.bash"

# An "#elif" is the branch a chain of platform or feature choices
# lands in when the "#if" above it doesn't, and the header scan had no
# idea the directive existed: whatever came after it was judged by the
# "#ifdef" at the top of the chain.  With USE_B given and USE_A not,
# the compiler reads extra.h, but the scan skipped it, so extra.c was
# never linked in and the link failed.

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
#elif defined(USE_B)
#include "extra.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
