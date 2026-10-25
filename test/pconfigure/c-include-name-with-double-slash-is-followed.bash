#include "harness_start.bash"

# What is inside the quotes of an #include is a file name and not C, so
# a "//" there starts no comment: the compiler opens lib//extra.h,
# which is lib/extra.h.  The scan blanked the line from the "//"
# onwards, looked for a file called "lib", found a directory, and never
# saw the header -- so extra.c was left out of the link.

mkdir -p src/lib

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
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
#include "lib//extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
