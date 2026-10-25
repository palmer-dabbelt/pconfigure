#include "harness_start.bash"

# The same "//" between angle brackets.  A '<' there is no less than a
# header name's opening bracket, and what runs to the '>' is a file
# name and not C, so the include of lib//extra.h is an include of
# lib/extra.h.  Blanked from the "//" onwards it named nothing the
# scan could find, and extra.c was left out of the link.

mkdir -p src/lib

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isrc
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
#include <lib//extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
