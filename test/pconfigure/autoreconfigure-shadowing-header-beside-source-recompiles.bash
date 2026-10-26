#include "harness_start.bash"

# '#include "x.h"' looks beside the source before it looks down the -I
# list, so a src/x.h written after the first build changes what main.c
# compiles to while no file the build was told about changed.  Without
# AUTORECONFIGURE that is what a reconfigure is for: the scan finds
# src/x.h and the object is rebuilt.  Under AUTORECONFIGURE the scan
# is pdeps's, and the two modes are meant to build the same thing, so
# a reconfigure has to get the new header compiled in there too.  Its
# fragment once named only inc/x.h and was rewritten only when the
# source or its options changed, so the program went on printing the
# old value until a "make clean".

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

sleep 2
echo '#define V 2' > src/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "2"

# And having found it, the build settles rather than scanning again.
timeout 60 make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out
