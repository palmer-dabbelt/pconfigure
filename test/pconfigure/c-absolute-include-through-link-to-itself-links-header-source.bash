#include "harness_start.bash"

# A link inside the project that points back at the project itself
# means an absolute path to a header has more than one leading part
# that is the project: "$tempdir" and "$tempdir/self" both are.  The
# longest one is the spelling a rule would use -- src/extra.h rather
# than self/src/extra.h -- and only that one has extra.c beside it as
# far as the build is concerned, so the header has to come out that
# way for the source behind it to be linked.

mkdir -p src
ln -s . self
cd self

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/extra.h <<'EOF'
int extra(void);
EOF

cat >src/extra.c <<'EOF'
int extra(void) { return 7; }
EOF

cat >src/main.c <<EOF
#include <stdio.h>
#include "$PWD/src/extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
grep -q '^obj/src/main\.c/[^ ]*\.o: src/main\.c src/extra\.h$' Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "7"
