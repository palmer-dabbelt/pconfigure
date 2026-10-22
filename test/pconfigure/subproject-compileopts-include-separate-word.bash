#include "harness_start.bash"

# A subproject writes its include path the way it sees it, from its
# own directory -- the same as subprojects-sibling-headers.bash does
# with "-I../b/src" -- and pconfigure puts the subproject's directory
# on the front so the path still means that from the top of the tree.
#
# Only a COMPILEOPTS that is exactly one "-Idir" word gets that
# treatment.  "-I inc" is the same flag spelled with a space, which
# gcc accepts, and it comes out as "-Ia/ inc": an include directory
# that is the subproject itself, followed by a bare "inc" that the
# compiler takes for a second input file and refuses ("cannot specify
# -o with multiple files").  LINKOPTS already reads "-L dir" as the
# one flag it is, and the compile side has no reason to differ.

mkdir -p a/src a/inc

cat >Configfile <<EOF
SUBPROJECTS += a
EOF

cat >a/Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -I inc
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
