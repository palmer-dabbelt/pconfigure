#include "harness_start.bash"

# Under AUTORECONFIGURE the headers a source reads go into a fragment
# pdeps writes, each with an empty rule of its own so that one which is
# deleted doesn't stop the build.  A header named 'v$1.h' went in bare,
# where make reads '$1' as a variable: the prerequisite became
# 'src/v.h', which isn't there, its empty rule "remade" it, the
# fragment was stale again, and make restarted forever without
# compiling anything.  The timeout is what turns that hang into a
# failure.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = true
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >'src/v$1.h' <<'EOF'
#define VALUE 7
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "v$1.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 120 make $MAKE_ARGS
test "$(./bin/app)" = "7"

sleep 1
cat >'src/v$1.h' <<'EOF'
#define VALUE 8
EOF
timeout 120 make $MAKE_ARGS
test "$(./bin/app)" = "8"
