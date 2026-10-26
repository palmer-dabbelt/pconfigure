#include "harness_start.bash"

# A brace needs no comma to be expanded by bash: "{1..2}" is a
# sequence.  So a BINARIES called "v{1..2}" was linked as "-o bin/v1
# bin/v2", and failed on the input that was never there.  It is refused
# at its line like the comma spelling, by the same '{'.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
cat >Configfile <<'EOT2'
LANGUAGES   += c
BINARIES    += v{1..2}
SOURCES     += main.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a BINARIES with a brace sequence in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "BINARIES has a '{' in it: 'v{1..2}'" out
test ! -e Makefile
