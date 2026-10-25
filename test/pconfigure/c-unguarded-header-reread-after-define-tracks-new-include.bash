#include "harness_start.bash"

# A header with no include guard is read again every time it is
# included, and what it includes can depend on what has been defined
# by then.  Here the second inclusion of cfg.h is the only one that
# pulls in extra.h, so the scan has to read cfg.h again rather than
# skipping a file it has seen before -- or extra.h drops out of the
# object's prerequisites and editing it rebuilds nothing.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += tool
SOURCES   += main.c
EOF2

cat >src/main.c <<'EOF2'
#include "cfg.h"
#define WANT_EXTRA 1
#include "cfg.h"
int main(void) { return EXTRA_VALUE; }
EOF2

cat >src/cfg.h <<'EOF2'
#ifdef WANT_EXTRA
#include "extra.h"
#endif
EOF2

cat >src/extra.h <<'EOF2'
#define EXTRA_VALUE 0
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
grep "^obj/.*main\.c.*:" Makefile | cut -c1-300
make $MAKE_ARGS
./bin/tool

sleep 1
sed -i 's/EXTRA_VALUE 0/EXTRA_VALUE 7/' src/extra.h
make $MAKE_ARGS
set +e
./bin/tool
test "$?" = 7
