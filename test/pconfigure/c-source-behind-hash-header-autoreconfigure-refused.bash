#include "harness_start.bash"

# The same refusal for a source behind a header, under AUTORECONFIGURE,
# where the walk is pdeps' while the build runs.  'notes#1.c' left bare
# on the rules pdeps wrote cut them off at 'src/notes'; what has to
# happen instead is a build that stops and says why, rather than one
# that stops on a line of generated text or never stops at all.

mkdir -p src

cat >Configfile <<'EOF2'
AUTORECONFIGURE = true
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/notes#1.h' <<'EOF2'
int extra(void);
EOF2

cat >'src/notes#1.c' <<'EOF2'
int extra(void) { return 7; }
EOF2

cat >src/main.c <<'EOF2'
#include "notes#1.h"
int main(void) { return extra(); }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
set +e
timeout 120 make $MAKE_ARGS > out 2>&1
status="$?"
set -e
cat out
test "$status" != "0"
test "$status" != "124"
grep -q "'src/main.c' reads 'src/notes#1.h', and the source behind it, 'src/notes#1.c', has a '#' in its name" out
