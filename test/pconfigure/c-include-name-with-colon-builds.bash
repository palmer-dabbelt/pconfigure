#include "harness_start.bash"

# A ':' in a header the scan finds -- 'ver:1.h', an include gcc reads
# without complaint -- was written bare onto rule lines, where make
# takes it for a second target separator and refuses the whole
# Makefile with 'multiple target patterns'.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/ver:1.h' <<'EOF2'
#define VALUE 7
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
#include "ver:1.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"

# And it is a prerequisite as the file it is: an edit to it is seen.
sleep 1
cat >'src/ver:1.h' <<'EOF2'
#define VALUE 8
EOF2
make $MAKE_ARGS
test "$(./bin/app)" = "8"
