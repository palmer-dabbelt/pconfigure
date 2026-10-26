#include "harness_start.bash"

# A '#' starts a comment on a make rule line, so a header found by
# the scan called 'notes#1.h' cut the object's prerequisite list off
# at 'src/notes', which no rule makes, and make stopped.  The compiler
# is happy with the name; it is pconfigure that has to write it so
# make reads back the file it means, the way a GENERATE script's
# --deps paths already are.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/notes#1.h' <<'EOF2'
#define VALUE 7
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
#include "notes#1.h"
int main(void) { printf("%d\n", VALUE); return 0; }
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"

# And it is a prerequisite as the file it is: an edit to it is seen.
sleep 1
cat >'src/notes#1.h' <<'EOF2'
#define VALUE 8
EOF2
make $MAKE_ARGS
test "$(./bin/app)" = "8"
