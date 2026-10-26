#include "harness_start.bash"

# A directory that turns up where an include might have been found is
# no header: the scan passes over it and goes on down the -I list.  It
# is still a reason to look again, but having looked, the build has to
# settle -- a fragment that kept asking to be rewritten for a path the
# scan would never take is a make that starts over for ever.

mkdir -p src inc

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += app
COMPILEOPTS     += -Iinc
SOURCES         += main.c
EOC

echo '#define V 1' > inc/x.h

cat >src/main.c <<'EOS'
#include <stdio.h>
#include "x.h"
int main(void) { printf("%d\n", V); return 0; }
EOS

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "1"

mkdir src/x.h

timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "1"

timeout 60 make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out
