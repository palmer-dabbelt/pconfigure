#include "harness_start.bash"

# A header that shadows the one a source was compiled against need not
# be newer than anything: "cp -p" or a tar extract brings one in with
# whatever date it had.  So what has to rescan the source is the
# header being there at all, not its timestamp -- and once a rescan
# has to happen, a plain make is as good a place to do it as a
# reconfigure, since pdeps is what does the scanning either way.

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

echo '#define V 2' > src/x.h
touch -t 200001010000 src/x.h

timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "2"

timeout 60 make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out
