#include "harness_start.bash"

# The manual: a COMPILEOPTS under a SOURCES is "for just that source".
# The SOURCES after it starts again from the target's options, so the
# -D written for b.c reaches neither the a.c before it nor the c.c
# after it.  Three sources so that "after" is tested as well as
# "before", and none of them share a header, so nothing but the
# per-source scoping decides which object sees the -D.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES   += c

BINARIES    += app
SOURCES     += a.c
SOURCES     += b.c
COMPILEOPTS += -DMARK=1
SOURCES     += c.c
EOF

for f in a b c
do
    cat >src/$f.c <<EOF
#ifdef MARK
int $f(void) { return 1; }
#else
int $f(void) { return 0; }
#endif
EOF
done

cat >>src/a.c <<'EOF'
#include <stdio.h>
int b(void);
int c(void);
int main(void) { printf("%d%d%d\n", a(), b(), c()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
test "$(./bin/app)" = "010"
