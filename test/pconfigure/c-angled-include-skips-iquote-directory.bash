#include "harness_start.bash"

# "-iquote" adds a directory that only '#include "..."' looks in; an
# angled include never sees it.  A header scan that read every include
# flag as one search list in the order it was written would, with
# "-iquote src/q" ahead of "-Isrc/i", answer '#include <extra.h>' with
# src/q/extra.h -- a header the compiler never reads -- and link in
# the source behind it.  That source doesn't compile, so following
# it stops the build, while the one the compiler means is left out.

mkdir -p src/q src/i

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -iquote src/q
COMPILEOPTS += -Isrc/i
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/q/extra.h
echo '#error "src/q is only for quoted includes"' >src/q/extra.c
echo 'int extra(void);' >src/i/extra.h
echo 'int extra(void) { return 2; }' >src/i/extra.c

cat >src/main.c <<'EOF'
#include <stdio.h>
#include <extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The object depends on the header the compiler reads.
grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/i/extra.h

make $MAKE_ARGS
test "$(./bin/app)" = "2"
