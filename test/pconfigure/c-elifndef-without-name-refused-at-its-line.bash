#include "harness_start.bash"

# An "#elifndef" asks about a name, and one written without any is a
# branch with no question to answer.  The compiler stops at it; the
# scan runs first, so it says where the line is and what is missing
# rather than taking the branch as if some name were undefined.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >src/main.c <<'EOF2'
#ifdef USE_A
int main(void) { return 1; }
#elifndef
int main(void) { return 0; }
#endif
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS >pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out

grep -q "^src/main\.c:3: '#elifndef' has no name" pconfigure.out
