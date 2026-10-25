#include "harness_start.bash"

# A name that is "#undef"ed is no longer defined, and an "#ifdef" of it
# after that is off.  The scan tracks "#define" but has never heard of
# "#undef", so it took the branch below, followed the include, and
# built the source behind it.  Here that source doesn't compile, which
# is how the build says so.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#error "extra.c is only built WITH_EXTRA"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#define WITH_EXTRA
#undef WITH_EXTRA
#ifdef WITH_EXTRA
#include "extra.h"
#endif
int main(void) { printf("app\n"); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/extra\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "app"
