#include "harness_start.bash"

# A source in a subdirectory that reaches a header one level up with
# "../", next to a source that reaches the same header from beside it.
# The ".." is taken out of the path before the header is named, so the
# two spellings are one header, and the source behind it is built and
# linked once rather than once per spelling.

mkdir -p src/sub

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
SOURCES   += sub/other.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/sub/other.c <<'EOF'
#include "../extra.h"
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

# Both objects name the header the same way, there is exactly one
# object for the source behind it, and no source path still has the
# ".." in it.
for o in main other
do
    test "$(grep "^obj/src/\(sub/\)\?$o\.c/[^ ]*\.o:" Makefile | tr ' ' '\n' | grep -cx src/extra.h)" = 1
done
test "$(grep -c '^obj/src/extra\.c/[^ ]*\.o:' Makefile)" = 1
if grep -q 'src/[^ ]*\.\./' Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "7 8"
