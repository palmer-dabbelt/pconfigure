#include "harness_start.bash"

# A longer chain: the "#ifdef" and the first "#elif" are both false,
# the second "#elif" is true, and there is an "#else" after it.  Only
# the second "#elif" is read by the compiler.  The "#else" has to stay
# off even though nothing before the branch that was taken was true --
# which is the case a conditional that only remembers whether its
# current branch is on gets wrong, flipping the "#else" on as though
# it were the other half of the "#ifdef" alone.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DUSE_C
SOURCES     += main.c
EOF

cat >src/c.h <<'EOF'
int which(void);
EOF

cat >src/c.c <<'EOF'
#include "c.h"
int which(void) { return 3; }
EOF

cat >src/fallback.h <<'EOF'
int which(void);
EOF

cat >src/fallback.c <<'EOF'
#error "fallback.c is only built when none of USE_A, USE_B and USE_C is"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifdef USE_A
static int which(void) { return 1; }
#elif defined(USE_B)
static int which(void) { return 2; }
#elif defined(USE_C)
#include "c.h"
#else
#include "fallback.h"
#endif
int main(void) { printf("%d\n", which()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/fallback\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "3"
