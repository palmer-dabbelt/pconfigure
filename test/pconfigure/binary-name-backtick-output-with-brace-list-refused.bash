#include "harness_start.bash"

# A brace list can come out of a backtick command just as a backtick
# can, and is no safer for it: "a{b,c}" pasted into the link recipe is
# expanded by bash into "bin/ab bin/ac".  The line is refused as it
# reads after the command ran, the same as if the braces had been
# typed.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
cat >Configfile <<'EOT2'
LANGUAGES   += c
BINARIES    += `printf 'a{b,c}'`
SOURCES     += main.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a BINARIES whose backtick command printed a brace list was accepted" >&2
    exit 1
fi
cat out
grep -qF "Configfile:2 'BINARIES += a{b,c}'" out
grep -qF "error: BINARIES has a '{' in it: 'a{b,c}'" out
test ! -e Makefile
