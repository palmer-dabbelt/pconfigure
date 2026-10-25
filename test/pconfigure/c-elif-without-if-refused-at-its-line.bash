#include "harness_start.bash"

# An "#elif" with no conditional open before it has nothing to be the
# next branch of.  Read as one anyway, it would end the only thing
# there is to end -- the file itself -- and every include after it
# would quietly go unlisted.  It's a mistake the compiler stops at
# too, but the scan runs first, so it says where the line is.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#elif defined(USE_B)
int main(void) { return 0; }
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out

grep -q "^src/main\.c:2: '#elif defined(USE_B)' has no '#if' before it" pconfigure.out
