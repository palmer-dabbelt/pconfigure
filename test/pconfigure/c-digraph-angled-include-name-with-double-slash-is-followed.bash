#include "harness_start.bash"

# A header name follows "%:include" just as it follows "#include", so
# the "//" between these angle brackets is part of a file name and
# opens no comment.  Taken for one, the rest of the line was blanked,
# the include named nothing the scan could find, and extra.c was left
# out of the link.

mkdir -p src/lib

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isrc
SOURCES     += main.c
EOF2

cat >src/lib/extra.h <<'EOF2'
int extra(void);
EOF2

cat >src/lib/extra.c <<'EOF2'
#include "extra.h"
int extra(void) { return 7; }
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
%: include <lib//extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
