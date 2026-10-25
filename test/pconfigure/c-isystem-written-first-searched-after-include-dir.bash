#include "harness_start.bash"

# gcc searches every "-I" directory before any "-isystem" one, whatever
# order the two were written in -- that is what makes "-isystem" the
# place for a vendored copy that a project's own header should win
# over.  A header scan that took the flags in written order instead
# would let an "-isystem" written first shadow the "-I" for it: the
# object would get a prerequisite on a header the compiler never
# reads, and the source behind that header would be linked in.  That source doesn't compile here.

mkdir -p src/sys src/own

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -isystem src/sys
COMPILEOPTS += -Isrc/own
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/sys/extra.h
echo '#error "src/sys/extra.h is shadowed by -Isrc/own"' >src/sys/extra.c
echo 'int extra(void);' >src/own/extra.h
echo 'int extra(void) { return 3; }' >src/own/extra.c

cat >src/main.c <<'EOF'
#include <stdio.h>
#include <extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/own/extra.h

make $MAKE_ARGS
test "$(./bin/app)" = "3"
