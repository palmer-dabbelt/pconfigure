#include "harness_start.bash"

# c-angled-include-skips-iquote-directory.bash under AUTORECONFIGURE,
# where it's pdeps during the build rather than pconfigure that reads
# the includes.  An angled include never looks in an "-iquote"
# directory, so the source the compiler means is the one behind
# src/i/extra.h; the one behind src/q/extra.h doesn't compile, and a
# scan that treated "-iquote" as another "-I" would link it in.

mkdir -p src/q src/i

cat >Configfile <<'EOF'
AUTORECONFIGURE = true

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
make $MAKE_ARGS
test "$(./bin/app)" = "2"
