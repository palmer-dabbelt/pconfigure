#include "harness_start.bash"

# "-I./src/lib" names the same directory as "-Isrc/lib".  The scan
# found the header through it as ./src/lib/extra.h, and the source
# behind that, ./src/lib/extra.c, didn't start with "src/" -- so it was
# taken for a file outside the project's sources and never built, and
# the link stopped on an undefined reference.

mkdir -p src/lib

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -I./src/lib
SOURCES     += main.c
EOF

cat >src/lib/extra.h <<'EOF'
int extra(void);
EOF

cat >src/lib/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q '^obj/src/lib/extra\.c/[^ ]*\.o:' Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
