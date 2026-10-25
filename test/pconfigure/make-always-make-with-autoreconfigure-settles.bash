#include "harness_start.bash"

# "make -B" with AUTORECONFIGURE and AUTODEPS on: every included
# fragment and the Makefile itself are targets make is now told are
# always out of date, and make re-reads its makefiles after remaking
# them.  That has to finish rather than going round reconfiguring for
# ever, rebuild the program, and leave a tree a plain make then has
# nothing to do in.

mkdir -p src include

cat >Configfile <<'EOF'
AUTORECONFIGURE = true
AUTODEPS        = true

LANGUAGES += c

BINARIES  += hello
SOURCES   += hello.c
EOF

cat >include/hello.h <<'EOF'
#define ANSWER 0
EOF

cat >src/hello.c <<'EOF'
#include <hello.h>
int main(void) { return ANSWER; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./bin/hello

timeout 300 make $MAKE_ARGS -B > always.out 2>&1
cat always.out
grep -q "^CC	hello.c$" always.out
grep -q "^LD	hello$" always.out
test "$(grep -c "^PCONFIGURE$" always.out)" -le 1
./bin/hello

make $MAKE_ARGS > again.out
cat again.out
if grep -q "^CC\|^LD\|^PCONFIGURE" again.out
then
    exit 1
fi

exit 0
