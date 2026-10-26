#include "harness_start.bash"

# The other half of an "#elifdef" the scan doesn't know: once the
# "#ifdef" at the top of the chain is taken, every branch after it is
# off.  Without the directive the scan went on reading the "#ifdef"'s
# branch straight through the "#elifdef", followed the include in it,
# and linked other.c -- which doesn't compile -- into a program the
# compiler builds without it.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DUSE_A
COMPILEOPTS += -DUSE_B
SOURCES     += main.c
EOF

cat >src/other.h <<'EOF'
int other(void);
EOF

cat >src/other.c <<'EOF'
#error other.c is behind a branch that is never taken
EOF

cat >src/main.c <<'EOF'
#ifdef USE_A
int value(void) { return 0; }
#elifdef USE_B
#include "other.h"
#endif
int main(void) { return value(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "other" Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/app
