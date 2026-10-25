#include "harness_start.bash"

# A forced include is how a config.h usually gets into every source,
# and what it is for is the "#define"s the sources then test.  Those
# are defined before the source's first line, so an "#ifdef" in the
# source sees them: the header behind this one is read, and has to be
# a prerequisite, only because config.h turned it on.
#
# AUTORECONFIGURE = false: pconfigure reads the options under false
# and pdeps does under true.

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE = false

LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -include src/config.h
SOURCES     += main.c
EOF

cat >src/config.h <<'EOF'
#define HAVE_EXTRA
EOF

cat >src/extra.h <<'EOF'
#define VALUE 1
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#ifdef HAVE_EXTRA
#include "extra.h"
#else
#define VALUE 0
#endif
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "1"

find . -type f -exec touch -d '2000-01-01' {} +

cat >src/extra.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./bin/app)" = "2"
