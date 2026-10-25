#include "harness_start.bash"

# "-Isrc/lib/" with the slash on the end is as good a spelling of the
# directory as any to the compiler.  The scan glued the header's name
# onto it with another slash and kept both, so a header main.c finds
# through the include path came out as src/lib//extra.h, while the
# same header found from beside it was src/lib/extra.h.  The source
# behind it was found under both names and linked twice.

mkdir -p src/lib

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isrc/lib/
SOURCES     += main.c
SOURCES     += lib/other.c
EOF

cat >src/lib/extra.h <<'EOF'
int extra(void);
EOF

cat >src/lib/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/lib/other.c <<'EOF'
#include "extra.h"
int other(void) { return extra() + 1; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "extra.h"
int other(void);
int main(void) { printf("%d %d\n", extra(), other()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
test "$(grep -c '^obj/[^ ]*extra\.c/[^ ]*\.o:' Makefile)" -le 1
make $MAKE_ARGS
test "$(./bin/app)" = "7 8"
