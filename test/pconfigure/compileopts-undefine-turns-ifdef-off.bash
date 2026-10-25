#include "harness_start.bash"

# "-UNAME" on a command line undoes a "-DNAME" written before it, and
# the compiler then skips whatever an "#ifdef NAME" guards.  The
# header scan only reads the "-D"s, so it still takes the branch: the
# header inside it becomes a prerequisite and the source behind that
# header is compiled and linked.  That source doesn't compile, which
# is how a program the compiler would build fine fails to.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
COMPILEOPTS += -DEXTRA -UEXTRA
SOURCES     += main.c
EOF

echo 'int extra(void);' >src/extra.h
echo '#error "EXTRA was undefined, so nothing reads extra.h"' >src/extra.c

cat >src/main.c <<'EOF'
#ifdef EXTRA
#include "extra.h"
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q 'src/extra' Makefile
then
    exit 1
fi

make $MAKE_ARGS
./bin/app
