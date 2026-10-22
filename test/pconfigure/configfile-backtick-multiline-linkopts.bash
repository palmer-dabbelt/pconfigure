#include "harness_start.bash"

# The same as a COMPILEOPTS, but for the line where it bites hardest:
# a link line that came out of a script printing one library per line.
# Each library has to stay a word of its own, or the linker is asked
# for a library called "m-lc" and nothing links.
mkdir -p src
cat >src/main.c <<'EOF'
#include <math.h>
int main(int argc, char **argv) { (void)argv; return (int)sqrt((double)argc) - 1; }
EOF

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
LINKOPTS    += `echo -lm; echo -lc`
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

if grep -q -- "-lm-lc" Makefile
then
    echo "two lines of backtick output were glued into one word" >&2
    exit 1
fi
grep -q -- "-lm -lc" Makefile

make $MAKE_ARGS
./bin/main
