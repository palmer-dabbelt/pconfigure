#include "harness_start.bash"

# A source named outright, with a COMPILEOPTS of its own, that another
# source also reaches through a header.  It is still the one source,
# and it is built the way its own SOURCES line says: util.c cannot
# compile without UTIL_VALUE, so building it the target's way -- or
# main.c's way -- is a compile error rather than a quiet second
# object, and building it both ways is "multiple definition of util".
#
# AUTORECONFIGURE = true, so this is the half where pdeps works the
# dependencies out during the build; the half where pconfigure walks
# them itself has a test of its own.

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
SOURCES     += util.c
COMPILEOPTS += -DUTIL_VALUE=7
EOF

cat >src/util.h <<'EOF'
int util(void);
EOF

cat >src/util.c <<'EOF'
#include "util.h"
int util(void) { return UTIL_VALUE; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "util.h"
int main(void) { printf("%d\n", util() * 3); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "21"

test "$(ls obj/src/util.c/*-static.o | wc -l)" -eq 1
