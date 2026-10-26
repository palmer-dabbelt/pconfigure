#include "harness_start.bash"

# A "#include \"x.h\"" finds a header beside its source before it
# looks in a -I directory, so a src/x.h that appears after the first
# build takes over from inc/x.h.  Without AUTORECONFIGURE nothing in
# the Makefile can notice that on its own; the next reconfigure is what
# has to.  Its scan should pick the new header, the object should now
# depend on it, and since it is newer than the object the program is
# recompiled -- and the header that lost should stop being something
# the object waits on, or every edit to it would recompile for nothing.

mkdir -p src inc

cat >Configfile <<'EOC'
LANGUAGES   += c
BINARIES    += app
COMPILEOPTS += -Iinc
SOURCES     += main.c
EOC

echo '#define V 1' > inc/x.h

cat >src/main.c <<'EOS'
#include <stdio.h>
#include "x.h"
int main(void) { printf("%d\n", V); return 0; }
EOS

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
echo '#define V 2' > src/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
grep -q 'src/x\.h' Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "2"

# The header that lost is no longer something the object waits on.
sleep 2
echo '#define V 3' > inc/x.h
make $MAKE_ARGS > settled.log 2>&1
cat settled.log
grep -q "Nothing to be done" settled.log
