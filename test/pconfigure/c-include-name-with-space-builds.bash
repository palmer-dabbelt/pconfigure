#include "harness_start.bash"

# A header's name is whatever the include says, and nothing stops it
# having a space in it: the compiler opens 'src/my extra.h' and the
# scan finds it.  It went into the Makefile as it was, as a
# prerequisite of the object, where make splits words at a space, so
# make went looking for 'src/my' and stopped with 'No rule to make
# target'.  Nothing in the Configfile names the header, so this is the
# scan's to write in a way make reads back.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/my extra.h' <<'EOF2'
#define VALUE 7
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
#include "my extra.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"

# And it is a prerequisite as the file it is: an edit to it is seen.
sleep 1
cat >'src/my extra.h' <<'EOF2'
#define VALUE 8
EOF2
make $MAKE_ARGS
test "$(./bin/app)" = "8"
