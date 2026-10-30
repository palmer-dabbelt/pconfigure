#include "harness_start.bash"

# A subproject writes "-include config.h" meaning the config.h beside
# its own Configfile, which is where a compiler run from its directory
# would look first.  The compiler pconfigure runs is run from the top
# of the tree, where that name means the top's own config.h, so the
# subproject's directory has to go on the front the way it does for
# "-I".  The top has a config.h of its own here so that reading the
# wrong one is a wrong answer and not just a missing file, and the
# edit at the end checks that the subproject's is the prerequisite.

mkdir -p a/src

cat >Configfile <<'EOF'
SUBPROJECTS += a
EOF

cat >config.h <<'EOF'
#define VALUE 100
EOF

cat >a/Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -include config.h
SOURCES     += main.c
EOF

cat >a/config.h <<'EOF'
#define VALUE 1
EOF

cat >a/src/main.c <<'EOF'
#include <stdio.h>
int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
cat a/obj/Makefile.a
make $MAKE_ARGS
test "$(./a/bin/app)" = "1"

find . -type f -exec touch -t 200001010000 {} +

cat >a/config.h <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./a/bin/app)" = "2"
