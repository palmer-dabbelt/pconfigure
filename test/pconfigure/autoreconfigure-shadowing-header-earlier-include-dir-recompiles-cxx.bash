#include "harness_start.bash"

# The -I list is searched in order, so a header written into the first
# directory after a build that found it in the second changes the
# program.  A reconfigure without AUTORECONFIGURE scans again and
# notices; under AUTORECONFIGURE the fragment that named inc2/x.h was
# rewritten only when the source or its options changed, so the C++
# program kept the value from the header that had been shadowed.  The
# C twin of this is
# autoreconfigure-shadowing-header-beside-source-recompiles.

mkdir -p src inc1 inc2

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c++
BINARIES        += app
COMPILEOPTS     += -Iinc1
COMPILEOPTS     += -Iinc2
SOURCES         += main.c++
EOC

echo '#define V 1' > inc2/x.h

cat >src/main.c++ <<'EOS'
#include <cstdio>
#include "x.h"
int main() { std::printf("%d\n", V); return 0; }
EOS

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
echo '#define V 2' > inc1/x.h

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 60 make $MAKE_ARGS
test "$(./bin/app)" = "2"

timeout 60 make $MAKE_ARGS > settled.out 2>&1
cat settled.out
grep -q "Nothing to be done" settled.out
