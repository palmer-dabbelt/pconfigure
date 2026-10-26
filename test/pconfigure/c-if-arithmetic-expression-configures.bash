#include "harness_start.bash"

# "#if N * 2" is ordinary preprocessor arithmetic, and the expression
# reader has no arithmetic: it found no operator it knew in "N * 2",
# fell off the end and aborted with "Unable to parse function" and the
# three tokens, naming neither the file nor the line.  A source the
# compiler builds is a source pconfigure has to be able to read past,
# even when it can't work out which way the "#if" goes.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF

cat >src/main.c <<'EOF'
#define N 3
#if N * 2
int value(void) { return 0; }
#else
int value(void) { return 1; }
#endif
int main(void) { return value(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app
