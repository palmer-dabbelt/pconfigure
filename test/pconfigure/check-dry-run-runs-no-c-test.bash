#include "harness_start.bash"

# The C half of "make -n check runs nothing": a test written in C has
# its check rule emitted by a different language than a BASH one does,
# and the two are separate copies of the same recipe, so one being
# right says nothing about the other.

mkdir -p src test/t

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES += t
SOURCES  += t.c
TESTSRC  += side-effect.c
EOF

cat >src/t.c <<'EOF'
int main(void) { return 0; }
EOF

cat >test/t/side-effect.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
int main(void)
{
    char path[4096];
    FILE *f;
    snprintf(path, sizeof(path), "%s/ran.log", getenv("PTEST_SRCDIR"));
    f = fopen(path, "a");
    if (f == NULL)
        return 2;
    fprintf(f, "ran\n");
    fclose(f);
    return 0;
}
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS check
test "$(cat ran.log)" = "ran"
rm ran.log

# A result that is missing is the plainest way to be out of date, and
# needs nothing rebuilt to get there.
rm check/t/side-effect.c

make $MAKE_ARGS -n check > dry.out
cat dry.out
grep -q "ptest' .*--out check/t/side-effect.c" dry.out

test ! -e ran.log
test ! -e check/t/side-effect.c

exit 0
