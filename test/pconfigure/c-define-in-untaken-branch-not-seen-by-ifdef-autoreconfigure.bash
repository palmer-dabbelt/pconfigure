#include "harness_start.bash"

# The same untaken "#define" as without AUTORECONFIGURE, asked by the
# build rather than by pconfigure.  pdeps reads the source with the
# same scan, so it too took USE_EXTRA for defined and pulled extra.c,
# which can't be compiled, into the link.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true
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
make $MAKE_ARGS
cat obj/src/main.c/*.d

if cat obj/src/main.c/*.d | grep -q "extra"
then
    exit 1
fi

./bin/app
