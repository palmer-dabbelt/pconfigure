#include "harness_start.bash"

# "-D" and "-U" are taken in the order they're written, by the
# compiler and so by the scan: a "-UFAST" and then a "-DFAST" leaves
# FAST defined.  A scan that took every "-U" as having the last word
# would turn the "#ifdef" below off, leave fast.h off the
# prerequisites and fast.c out of the link, and the program wouldn't
# link.

mkdir -p src

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += -UFAST

BINARIES    += app
COMPILEOPTS += -DFAST
SOURCES     += main.c
EOC

echo 'int fast(void);' >src/fast.h
echo 'int fast(void) { return 4; }' >src/fast.c

cat >src/main.c <<'EOC'
#include <stdio.h>
#ifdef FAST
#include "fast.h"
#endif
int main(void) { printf("%d\n", fast()); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/fast.h

make $MAKE_ARGS
test "$(./bin/app)" = "4"
