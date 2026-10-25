#include "harness_start.bash"

# -I'src/lib' is -Isrc/lib once the shell has read it, so the compiler
# finds <extra.h> in src/lib.  The header scan looks in the same
# directories the compiler does, which means taking the quotes off
# the way the shell does: a scan that went looking in a directory
# called "'src/lib'" never finds extra.h, never finds extra.c behind
# it, and the link fails on a function main.c was promised.

mkdir -p src/lib

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += -I'src/lib'
BINARIES    += app
SOURCES     += main.c
EOC

cat >src/lib/extra.h <<'EOC'
int extra(void);
EOC

cat >src/lib/extra.c <<'EOC'
#include <extra.h>
int extra(void) { return 7; }
EOC

cat >src/main.c <<'EOC'
#include <stdio.h>
#include <extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "7"
