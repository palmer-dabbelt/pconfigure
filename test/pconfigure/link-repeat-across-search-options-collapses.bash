#include "harness_start.bash"

# A library named again with only search options in between -- a "-L"
# or an rpath, which say where to look but bring in nothing that could
# want a symbol -- is a request the linker has already satisfied, and
# ld64 warns about it as a duplicate.  Keeping the second copy of a
# library is only right when something that could need it again comes
# between the two, so this repeat still collapses to one.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libone.so
SOURCES   += one.c

LIBRARIES += libtwo.so
SOURCES   += two.c

BINARIES  += app
LINKOPTS  += -lone -Wl,-rpath,/nonexistent -L lib -lone -ltwo
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

# The search options stay, and the second "-lone" is gone.
grep -q -- "-lone -Wl,-rpath,/nonexistent -L lib -ltwo" Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "3"
