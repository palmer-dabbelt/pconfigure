#include "harness_start.bash"

# The Configfile reader runs what is between two backticks itself, but
# pastes the output into the line unexamined, so a command whose output
# has a backtick in it puts one in the name.  Here "a`b" was written
# bare into the link recipe, where bash read the backtick as the start
# of a command substitution that never ends.  The refusal is asked of
# the line as it is after the command ran, so it catches this one too,
# shows the line with the output in place, and writes no Makefile.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
cat >Configfile <<'EOT2'
LANGUAGES   += c
BINARIES    += `printf 'a\140b'`
SOURCES     += main.c
EOT2

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a BINARIES whose backtick command printed a '\`' was accepted" >&2
    exit 1
fi
cat out
grep -qF "Configfile:2 'BINARIES += a\`b'" out
grep -qF "error: BINARIES has a '\`' in it: 'a\`b'" out
test ! -e Makefile
