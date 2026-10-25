#include "harness_start.bash"

# A source that reaches a header beside the project rather than in it,
# by climbing out of src/ and then out of the project.  The compiler
# finds it.  The scan took the ".." out of the path by popping one
# directory per "..", and the second one popped a list that was
# already empty -- so pconfigure died of a segfault before it had
# written a Makefile.  The ".." that climbs out of the project has
# nothing to take off and stays, so the object still depends on the
# header where it really is.

mkdir -p proj/src shared
cd proj

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
EOF

cat >../shared/shared.h <<'EOF'
#define SHARED 3
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "../../shared/shared.h"
int main(void) { printf("%d\n", SHARED); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q '^obj/src/main\.c/[^ ]*\.o: src/main\.c \.\./shared/shared\.h' Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "3"
