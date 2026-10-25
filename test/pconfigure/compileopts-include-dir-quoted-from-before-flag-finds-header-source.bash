#include "harness_start.bash"

# '-Ilib' is the shell's -Ilib, quote and all, the same as -I'lib'.
# The header scan matched "-I" against the word as written, which
# starts with a quote, so it never searched lib/: the "#include
# <extra.h>" found nothing, and extra.c, the source behind that
# header, was left out of the link.

mkdir -p src/lib

cat >Configfile <<'EOC'
LANGUAGES   += c
COMPILEOPTS += '-Isrc/lib'
BINARIES    += app
SOURCES     += main.c
EOC

echo 'int extra(void);' >src/lib/extra.h
echo 'int extra(void) { return 6; }' >src/lib/extra.c

cat >src/main.c <<'EOC'
#include <stdio.h>
#include <extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "6"
