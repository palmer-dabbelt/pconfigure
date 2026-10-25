#include "harness_start.bash"

# A double quote between single quotes is a character and opens no
# string.  Taken for the start of one, it ran to the end of the line
# and hid the "/*" behind it, so the block it opens -- and the include
# the compiler never reads inside it -- was read as live, and the
# source behind that include was built.  Here that source doesn't
# compile, which is how the build says so.

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
static const char quote = '"'; /* disabled until extra is ready:
#include "extra.h"
*/
int main(void) { printf("%c\n", quote); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/extra\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = '"'
