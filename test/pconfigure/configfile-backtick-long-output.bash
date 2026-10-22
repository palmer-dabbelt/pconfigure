#include "harness_start.bash"

# What a backtick prints goes into the line it was written on, and a
# command that prints a long list prints it as one long line.  That
# line is read the same way a Configfile is, so a reader that hands it
# back in pieces has each piece's whitespace trimmed on its own -- and
# a piece that started or ended on the space between two flags glues
# them together.  Every flag here is four bytes with its space, so a
# cut at any multiple of a power of two lands on one of those spaces.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c

BINARIES    += main
COMPILEOPTS += `for i in $(seq 1 1500); do printf -- '-DA '; done; echo`
SOURCES     += main.c
EOF

$PTEST_BINARY $PCONFIGURE_ARGS

# All 1500 flags arrive, and none of them arrive stuck to the next.
if grep -q -- "-DA-D" Makefile
then
    exit 1
fi
test "$(grep -o -- "-DA" Makefile | wc -l)" -ge 1500

make $MAKE_ARGS
./bin/main
