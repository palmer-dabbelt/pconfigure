#include "harness_start.bash"

# A quoted include looks in the includer's directory, then in every
# "-iquote" directory, and only then along "-I" -- so an "-iquote"
# written after an "-I" still comes first for '#include "..."'.  A
# scan that went by the order the lines were written would settle on
# the "-I" copy: the object would depend on a header the compiler
# doesn't read, an edit to the one it does read would rebuild nothing,
# and the source linked in would be the wrong one.  The wrong one doesn't compile here.

mkdir -p src/i src/q

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -Isrc/i
COMPILEOPTS += -iquote src/q
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/i/extra.h
echo '#error "src/i is searched after the -iquote directory"' >src/i/extra.c
echo 'int extra(void);' >src/q/extra.h
echo 'int extra(void) { return 5; }' >src/q/extra.c

cat >src/main.c <<'EOF'
#include <stdio.h>
#include "extra.h"
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/q/extra.h

make $MAKE_ARGS
test "$(./bin/app)" = "5"
