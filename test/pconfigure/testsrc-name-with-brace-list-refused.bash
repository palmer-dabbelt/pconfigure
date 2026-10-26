#include "harness_start.bash"

# A test's name goes into the pbashc and ptest recipes bare, and bash
# expanded the braces in "t{a,b}.bash" into two words, so pbashc was
# handed two inputs and the test never ran: "make check" failed with
# pbashc's usage text and nothing about the Configfile line.  The
# TESTSRC line is refused instead, naming it.
mkdir -p src test/app
echo 'int main(void) { return 0; }' > src/app.c
echo 'true' > 'test/app/t{a,b}.bash'
cat >Configfile <<'EOT2'
LANGUAGES   += c
LANGUAGES   += bash
BINARIES    += app
SOURCES     += app.c
TESTSRC     += t{a,b}.bash
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a TESTSRC with a brace list in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:5" out
grep -qF "TESTSRC has a '{' in it: 't{a,b}.bash'" out
test ! -e Makefile
