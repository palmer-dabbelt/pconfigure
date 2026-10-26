#include "harness_start.bash"

# A source's name is pasted bare into the compile line the same way a
# target's is, so "cc -c src/v{1..3}.c" was handed three files that
# don't exist, and the object's "-o" named three outputs.  The SOURCES
# line is refused, naming it, rather than left to a compiler error
# about files nobody wrote.
mkdir -p src
echo 'int main(void) { return 0; }' > 'src/v{1..3}.c'
cat >Configfile <<'EOT2'
LANGUAGES += c

BINARIES  += hello
SOURCES   += v{1..3}.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a SOURCES with a brace sequence in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:4" out
grep -qF "SOURCES has a '{' in it: 'v{1..3}.c'" out
test ! -e Makefile
