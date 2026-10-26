#include "harness_start.bash"

# Inside "#if 0" the compiler evaluates nothing -- not even an "#if"
# it couldn't make sense of -- and "#if 0" is exactly where code that
# is off for now goes.  The scan worked out every "#if" it met before
# asking whether the branch around it was taken, so "#if A + B" in a
# dead block aborted pconfigure with "Unable to parse function" and no
# file name.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/main.c <<'EOF'
#if 0
#if A + B
#error never compiled
#endif
#endif
int main(void) { return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app
