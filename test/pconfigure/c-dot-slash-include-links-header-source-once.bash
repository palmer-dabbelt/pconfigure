#include "harness_start.bash"

# One source spells the header "extra.h" and another "./extra.h".  They
# are the same file, and the source behind it is one source.  The scan
# kept the "./" in the path it found, so the header turned into two
# names, extra.c was found under both of them, and it was compiled and
# linked twice -- a "multiple definition" out of a program nothing is
# wrong with.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
SOURCES   += other.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/other.c <<'EOF'
#include "./extra.h"
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
