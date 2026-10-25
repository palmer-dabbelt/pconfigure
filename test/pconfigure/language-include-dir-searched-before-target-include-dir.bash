#include "harness_start.bash"

# A language-wide "-I" goes on the command line ahead of a target's,
# so when both directories hold a header of the same name the
# language-wide one is what the compiler reads.  The header scan has
# to come to the same answer, or it links in the source behind the
# other copy: here that one doesn't compile, so following it would
# stop the build.

mkdir -p src/lang src/target

cat >Configfile <<'EOF'
LANGUAGES   += c
COMPILEOPTS += -Isrc/lang

BINARIES    += app
COMPILEOPTS += -Isrc/target
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/lang/extra.h
echo 'int extra(void) { return 11; }' >src/lang/extra.c
echo 'int extra(void);' >src/target/extra.h
echo '#error "src/target/extra.h is shadowed by the language-wide -I"' >src/target/extra.c

cat >src/main.c <<'EOF'
#include <stdio.h>
#include <extra.h>
int main(void) { printf("%d\n", extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep '^obj/src/main\.c/[^ ]*\.o:' Makefile | tr ' ' '\n' | grep -qx src/lang/extra.h
if grep -q 'src/target/extra' Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "11"
