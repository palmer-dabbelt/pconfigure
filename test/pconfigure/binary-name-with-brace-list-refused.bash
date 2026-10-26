#include "harness_start.bash"

# Every recipe runs under SHELL=/bin/bash, and bash expands braces: a
# name pasted bare into a recipe as "bin/a{b,c}" reaches the command as
# the two words "bin/ab bin/ac".  So a BINARIES called that was linked
# with "-o bin/ab bin/ac", handing the linker an output and an input
# nobody asked for, and "make clean" removed bin/ab and bin/ac rather
# than the program.  It is refused with the ';' and '&' a name can't
# carry either, naming the line, before any Makefile is written.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
cat >Configfile <<'EOT2'
LANGUAGES   += c
BINARIES    += a{b,c}
SOURCES     += main.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a BINARIES with a brace list in its name was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "BINARIES has a '{' in it: 'a{b,c}'" out
grep -q "brace" out
test ! -e Makefile
