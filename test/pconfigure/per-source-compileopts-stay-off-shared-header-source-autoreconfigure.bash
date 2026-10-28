#include "harness_start.bash"

# A COMPILEOPTS written under a SOURCES is, per the manual, "for just
# that source".  Two sources here read the same header, and the source
# behind that header gets found and built once for the target -- but
# only one of the two readers carries a -D of its own.  If that -D
# leaks onto the source found behind its header, util.c is compiled
# twice, once per set of options, and both objects land on one link
# line: "multiple definition of util".
#
# AUTORECONFIGURE = true, so this is the half where pdeps works the
# dependencies out during the build; the half where pconfigure walks
# them itself has a test of its own.

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
SOURCES     += other.c
COMPILEOPTS += -DOTHER_SCALE=2
EOF

cat >src/util.h <<'EOF'
int util(void);
EOF

cat >src/util.c <<'EOF'
#include "util.h"
int util(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "util.h"
int other(void);
int main(void) { printf("%d\n", util() + other()); return 0; }
EOF

cat >src/other.c <<'EOF'
#include "util.h"
int other(void) { return util() * OTHER_SCALE; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "21"

# One object for util.c, built the target's way.
test "$(ls obj/src/util.c/*-static.o | wc -l | tr -d ' ')" -eq 1
