#include "harness_start.bash"

# "make -k" keeps building whatever doesn't depend on what failed.
# One program that doesn't compile mustn't stop its unrelated sibling
# being built under -k, the result must be a failing make, and the
# broken program must not be left with anything in bin/ that looks
# like a build of it.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += broken
SOURCES   += broken.c

BINARIES  += fine
SOURCES   += fine.c
EOF

cat >src/broken.c <<'EOF'
int main(void) { return this is not C; }
EOF

cat >src/fine.c <<'EOF'
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

if make $MAKE_ARGS -k > make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -q "broken.c" make.out

test -x bin/fine
test ! -e bin/broken

exit 0
