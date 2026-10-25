#include "harness_start.bash"

# Two include directories with a header of the same name in each.  The
# compiler takes the first directory on the command line that has it,
# and so does the scan: the source behind the first one is the one
# that is linked in, and the other is never built.  The second one
# doesn't compile, so following it would stop the build.

mkdir -p src/one src/two

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isrc/one
COMPILEOPTS += -Isrc/two
SOURCES     += main.c
EOF

cat >src/one/extra.h <<'EOF'
int extra(void);
EOF

cat >src/one/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 1; }
EOF

cat >src/two/extra.h <<'EOF'
int extra(void);
EOF

cat >src/two/extra.c <<'EOF'
#error "src/two is shadowed by src/one"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# main.c's object depends on the header the compiler will actually
# read, and nothing at all is said about the shadowed one.
test "$(grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -cx src/one/extra.h)" = 1
if grep -q "src/two/" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "1"
