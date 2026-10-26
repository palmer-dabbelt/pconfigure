#include "harness_start.bash"

# An "#elifdef" is an "#elif" by another spelling, and one with no
# conditional open before it has nothing to be the next branch of any
# more than an "#elif" does.  Read as one anyway it would end the file
# itself, and every include after it would go unlisted, so it is
# refused at its line with the directive it was written as.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >src/main.c <<'EOF2'
#include <stdio.h>
#elifdef USE_B
int main(void) { return 0; }
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out

grep -q "^src/main\.c:2: '#elifdef USE_B' has no '#if' before it" pconfigure.out
grep -q "an '#elifdef' is the next branch" pconfigure.out
