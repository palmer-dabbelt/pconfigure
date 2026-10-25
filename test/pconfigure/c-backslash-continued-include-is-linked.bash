#include "harness_start.bash"

# A directive split across lines with a backslash is one line to the
# preprocessor, and an "#include" whose name is on the second half of
# it is an include like any other.  The scan joins the lines first, so
# it finds the header and the source behind it.

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
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include \
    "extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The header is a prerequisite of main.c's object, so editing it
# rebuilds main.c, and the source behind it is linked in, which is
# what lets the program link at all.
test "$(grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -cx src/extra.h)" = 1
grep -q '^obj/src/extra\.c/[^ ]*\.o:' Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "7"
