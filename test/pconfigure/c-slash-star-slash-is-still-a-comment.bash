#include "harness_start.bash"

# "/*/" opens a comment and doesn't close it: the "*" that would end it
# is the one that started it.  The scan took the three characters for
# a whole comment, so the include in the middle of the block below --
# which the compiler never reads -- was followed, and the source behind
# it was built.  Here that source doesn't compile, which is how the
# build says so.

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
#error "extra.c is commented out of the program"
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
/*/ disabled until extra is ready:
#include "extra.h"
*/
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
