#include "harness_start.bash"

# The usual shape of a feature switch: one branch for when the
# platform has something and an "#else" that defines a fallback name
# when it doesn't.  With HAVE_FAST given, the "#else" is skipped and
# USE_SLOW is never defined -- but the scan read the "#define" in it
# anyway, followed the "#ifdef USE_SLOW", and linked slow.c, whose
# slow() collides with the one main.c defines.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DHAVE_FAST
SOURCES     += main.c
EOF

cat >src/slow.h <<'EOF'
int slow(void);
EOF

cat >src/slow.c <<'EOF'
int slow(void) { return 1; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifdef HAVE_FAST
int slow(void) { return 2; }
#else
#define USE_SLOW
#endif

#ifdef USE_SLOW
#include "slow.h"
#endif

int main(void) { printf("%d\n", slow()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "2"
