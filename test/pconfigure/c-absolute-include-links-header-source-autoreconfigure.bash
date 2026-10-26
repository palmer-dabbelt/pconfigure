#include "harness_start.bash"

# An absolute "#include" under AUTORECONFIGURE, where pdeps does the
# scan.  It shares the lookup that put the includer's directory in
# front of an absolute name, so the header was never found, the source
# behind it never built, and the link failed.

mkdir -p src

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
#include "$tempdir/src/extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "7"
