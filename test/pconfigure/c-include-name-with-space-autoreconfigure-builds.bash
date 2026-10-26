#include "harness_start.bash"

# The same spaced header under AUTORECONFIGURE, where the list of what
# a source reads is written by pdeps into a fragment while the build
# runs, rather than by pconfigure into the Makefile.  The fragment gives
# each header an empty rule of its own as well as a place on the
# object's line, so the name has to be spelled for both sides of a
# rule; written bare, make split it at the space there too.

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/my extra.h' <<'EOF2'
#define VALUE 7
EOF2

cat >'src/50%.h' <<'EOF2'
#define OTHER 0
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
#include "my extra.h"
#include "50%.h"
int main(void) { printf("%d\n", VALUE + OTHER); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
timeout 120 make $MAKE_ARGS
test "$(./bin/app)" = "7"

sleep 1
cat >'src/my extra.h' <<'EOF2'
#define VALUE 8
EOF2
timeout 120 make $MAKE_ARGS
test "$(./bin/app)" = "8"

# A header that stops being read and is then deleted is what the empty
# rules are for: the build carries on rather than stopping on a file
# nothing makes.  The '%' one is there for this half, since on the
# left of a rule a bare '%' is a pattern and not the file.
sleep 1
cat >src/main.c <<'EOF2'
#include <stdio.h>
int main(void) { printf("9\n"); return 0; }
EOF2
rm 'src/my extra.h' 'src/50%.h'
timeout 120 make $MAKE_ARGS
test "$(./bin/app)" = "9"
