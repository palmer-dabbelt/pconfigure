#include "harness_start.bash"

# A "/*" inside a string literal opens no comment -- "logs/*.log" is
# a glob, the kind a program that looks for files has a dozen of.  The
# scan blanks comments without knowing what a string is, so it took
# the "/*" for the start of one and blanked everything after it,
# include and all.  extra.c was never found and the link failed.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
#include "extra.h"
int extra(void) { return 7; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
static const char *pattern = "logs/*.log";
#include "extra.h"
int main(void) { printf("%d %s\n", extra(), pattern); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7 logs/*.log"
