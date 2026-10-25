#include "harness_start.bash"

# A script's "#if" is refused, because pbashc can't work one out.  A C
# test is read the same strict way a script is when pconfigure looks
# through it for "#pconfigure" lines, and that strictness is not the
# same thing as being a script: its "#if"s are the compiler's to work
# out, and refusing them would make every C test with one in the
# first column a project that can't be configured.
mkdir -p src test/main

echo 'int main(void) { return 0; }' > src/main.c

cat >test/main/t.c <<'EOF2'
#if 0
#error "the compiler works this one out, not pconfigure"
#endif
int main(void) { return 0; }
EOF2

cat >Configfile <<'EOF2'
LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
TESTSRC   += t.c
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check

test "$(tar -xOf check/main/t.c ptest__return)" = 0
