#include "harness_start.bash"

# "-idirafter" is the fallback directory: the compiler only looks in it
# once every "-I", "-isystem" and system directory has come up empty,
# which is the point of writing one.  A header scan that read the
# flags in the order they were written would let an "-idirafter"
# written ahead of an "-I" win the scan while the "-I" wins the
# compiler, and that answer pulls in the source behind the fallback
# header, which here doesn't compile.

mkdir -p src/fallback src/own

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -idirafter src/fallback
COMPILEOPTS += -Isrc/own
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/fallback/extra.h
echo '#error "src/fallback is only searched last"' >src/fallback/extra.c
echo 'int extra(void);' >src/own/extra.h
echo 'int extra(void) { return 4; }' >src/own/extra.c

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/own/extra.h

make $MAKE_ARGS
test "$(./bin/app)" = "4"
