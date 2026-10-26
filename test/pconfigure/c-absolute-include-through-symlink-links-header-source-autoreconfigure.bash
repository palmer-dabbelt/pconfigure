#include "harness_start.bash"

# The same symlinked checkout under AUTORECONFIGURE, where pdeps does
# the scan from inside make.  It asks the same question of the same
# path to decide whether a header is the project's own, so a header
# named through the link has to come out as src/extra.h there too, or
# extra.c is never linked.

mkdir -p real/src
ln -s real link
cd link

cat >Configfile <<'EOF'
AUTORECONFIGURE = true
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 7; }
EOF

cat >src/main.c <<EOF
#include <stdio.h>
#include "$PWD/src/extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "7"
