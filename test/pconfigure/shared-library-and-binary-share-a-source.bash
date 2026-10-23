#include "harness_start.bash"

# One source compiled into both a shared library and a program: the
# library's copy has to be position-independent and the program's
# needn't be, so these are two objects, one per flavour, rather than
# one object reused -- and each target links its own.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libcommon.so
SOURCES   += common.c

BINARIES  += app
SOURCES   += common.c
SOURCES   += main.c
EOF

cat >src/common.c <<'EOF'
int common(void) { return 9; }
EOF

cat >src/main.c <<'EOF'
#include <stdio.h>
int common(void);
int main(void) { printf("%d\n", common()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

test -f obj/src/common.c/*-shared.o
test -f obj/src/common.c/*-static.o
grep -q -- "-c src/common.c -o obj/src/common.c/[0-9]*-shared.o -fPIC" Makefile

test "$(./bin/app)" = "9"

# The program carries its own copy rather than needing the library.
if readelf -d bin/app | grep -q "NEEDED.*libcommon"
then
    exit 1
fi
