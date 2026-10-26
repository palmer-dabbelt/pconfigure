#include "harness_start.bash"

# A "#define" in a branch the compiler skips defines nothing: that is
# the whole point of putting it inside an "#ifdef".  The header scan
# read every "#define" whatever branch it was in, so USE_EXTRA counted
# as defined here, the "#ifdef USE_EXTRA" below it was followed, and
# extra.c -- which this program never includes and which doesn't even
# compile -- was built and linked into it.

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
#error extra.c is behind a header nothing reads
EOF

cat >src/main.c <<'EOF'
#ifdef NEVER_DEFINED
#define USE_EXTRA
#endif

#ifdef USE_EXTRA
#include "extra.h"
#endif

int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "extra" Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/app
