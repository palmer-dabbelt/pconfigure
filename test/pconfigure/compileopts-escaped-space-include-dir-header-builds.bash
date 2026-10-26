#include "harness_start.bash"

# The same header as a package under a spaced directory, named by hand
# instead of through ppkg-config: "COMPILEOPTS += -I../my\ libs/include"
# is the spelling a shell wants, and the compile recipe gets it right.
# The header scan follows the escaped -I and finds the header, then
# writes its path into the Makefile as a prerequisite with the space
# bare -- two words to make, the first of which no rule builds -- and
# the build stops with "No rule to make target".
mkdir -p proj/src "my libs/include"

cat >"my libs/include/spaced.h" <<'EOF'
#define SPACED 6
EOF

cd proj

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += test
COMPILEOPTS += -I../my\ libs/include
SOURCES     += test.c
EOF

cat >src/test.c <<'EOF'
#include <spaced.h>
int main(void) { return SPACED; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

set +e
./bin/test
status="$?"
set -e
test "$status" = "6"

exit 0
