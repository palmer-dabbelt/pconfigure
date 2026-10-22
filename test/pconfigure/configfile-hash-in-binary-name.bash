#include "harness_start.bash"

# A '#' in a value is just a character to pconfigure -- a comment is
# only a line that starts with one -- but it's the start of a comment
# to make, wherever it appears on a rule line.  A BINARIES name with one
# in it becomes a target name with one in it, and make used to stop
# with "missing separator" on the first rule that named it.
#
# Nothing ever built with one of these in a name, so pconfigure
# refuses the line, naming it, before it writes anything: the
# alternative was a Makefile make couldn't read, and an error about a
# line of generated text that points nowhere near the Configfile line
# responsible.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += hello#world
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a name with a '#' in it was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "has a '#' in it" out
test ! -e Makefile
