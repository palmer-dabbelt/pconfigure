#include "harness_start.bash"

# A subproject writes its include path the way it sees it, from its
# own directory -- the same as subprojects-sibling-headers.bash does
# with "-I../b/src" -- and pconfigure puts the subproject's directory
# on the front so the path still means that from the top of the tree.
#
# "-isystem" is the other everyday way of naming an include
# directory -- it is what silences warnings from a vendored header --
# and it is written relative to the subproject for exactly the same
# reason "-I" is.  Nothing roots it, so it names the "inc" at the
# top of the tree and the header isn't found.

mkdir -p a/src a/inc

cat >Configfile <<EOF
SUBPROJECTS += a
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -isystem inc
SOURCES     += main.c
EOF

cat >a/inc/answer.h <<'EOF'
#define ANSWER 42
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
#include "answer.h"
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "42"
