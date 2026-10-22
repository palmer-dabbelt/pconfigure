#include "harness_start.bash"

# A COMPILEOPTS under a target, before any SOURCES, applies to every
# source linked into that target, "both explicitly and implicitly" in
# the manual's words -- so the source found behind a header is built
# with it too, in both of the ways dependencies get worked out.

mkdir -p src

for ar in false true
do
    rm -rf obj bin Makefile

    cat >Configfile <<EOF
AUTORECONFIGURE = $ar

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DSCALE=6
SOURCES     += main.c
EOF

    cat >src/util.h <<'EOF'
int util(void);
EOF

    cat >src/util.c <<'EOF'
#include "util.h"
int util(void) { return SCALE; }
EOF

    cat >src/main.c <<'EOF'
#include <stdio.h>
#include "util.h"
int main(void) { printf("%d\n", util() * SCALE); return 0; }
EOF

    $PTEST_BINARY $PCONFIGURE_ARGS
    cat Makefile
    make $MAKE_ARGS
    test "$(./bin/app)" = "36"
done
