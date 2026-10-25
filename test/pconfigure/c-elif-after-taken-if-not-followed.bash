#include "harness_start.bash"

# The other half of an "#elif": once a branch of the chain has been
# taken, none of the ones after it are, whatever they say.  The scan
# carried on past the "#elif" as though it were still inside the
# "#ifdef" that was taken, followed the include in a branch the
# compiler never reads, and built the source behind it -- which here
# only compiles when that branch is the one chosen.
#
# The "#elif" is written to be true on its own, so that what keeps its
# include out is the branch above it having been taken, and not the
# expression happening to come out false.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DUSE_A
SOURCES     += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#error "extra.c is only built when USE_A is not given"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifdef USE_A
static int extra(void) { return 1; }
#elif !defined(USE_B)
#include "extra.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/extra\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "1"
