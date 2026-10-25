#include "harness_start.bash"

# "#ifdef NAME" with something after the name is another line the
# compiler warns about and reads anyway, deciding on the name alone.
# The scan wrapped the whole of it in "defined(...)", couldn't parse
# what came back, and aborted with a list of tokens and no file name.
#
# VERBOSE is defined and LOGGING isn't, so the "#ifdef" here is taken
# and the "#ifndef" isn't, but only when the first name is the one
# asked about.  Each branch holds a header whose source either has to
# be linked in or can't be compiled, so a conditional decided on the
# wrong name fails the build.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DVERBOSE
SOURCES     += main.c
EOF

cat >src/quiet.h <<'EOF'
int quiet(void);
EOF

cat >src/quiet.c <<'EOF'
#error "quiet.c is only meant to be built without VERBOSE"
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
#ifdef VERBOSE LOGGING
#include "extra.h"
#endif
#ifndef VERBOSE LOGGING
#include "quiet.h"
#endif
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q "src/quiet\.[ch]" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "7"
