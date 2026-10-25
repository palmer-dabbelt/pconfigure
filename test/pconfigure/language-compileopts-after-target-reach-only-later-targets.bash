#include "harness_start.bash"

# The manual's recipe for building one set of targets one way and the
# next set another: "LANGUAGES += c" again, then a new language-wide
# COMPILEOPTS.  What that promises is that the later option reaches
# the targets written after it and not the ones above, while the
# earlier option still reaches both -- language-wide options build up,
# they don't reset.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c
COMPILEOPTS += -DONE=1

BINARIES    += first
SOURCES     += first.c

LANGUAGES   += c
COMPILEOPTS += -DTWO=2

BINARIES    += second
SOURCES     += second.c
EOF

for name in first second
do
    cat >src/$name.c <<'EOF'
#include <stdio.h>
#ifndef TWO
#define TWO 0
#endif
int main(void) { printf("%d %d\n", ONE, TWO); return 0; }
EOF
done

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS

test "$(./bin/first)" = "1 0"
test "$(./bin/second)" = "1 2"
