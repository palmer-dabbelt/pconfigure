#include "harness_start.bash"

# A library asked for twice is only worth naming once on the link line,
# and that holds whichever way it was spelled: "-l one" and "-lone" are
# the same request.  Dropping a repeat of the two-word spelling has to
# drop both of its words, though, because dropping just the "-l" leaves
# "one" behind as a bare word, which the linker reads as a file called
# "one" in the current directory and fails to find.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

LIBRARIES += libtwo.so
SOURCES   += two.c

BINARIES  += app
LINKOPTS  += -L lib -l one -lone -l one -l two
SOURCES   += main.c
EOF

cat >src/one.c <<'EOF'
int one(void) { return 1; }
EOF

cat >src/two.c <<'EOF'
int two(void) { return 2; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int one(void);
int two(void);
int main(void) { printf("%d\n", one() + two()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The first request for libone is the one that survives, with its word,
# and neither repeat leaves anything of itself behind.
grep -q -- "-l one -l two" Makefile
if grep -q -- "-lone" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "3"
