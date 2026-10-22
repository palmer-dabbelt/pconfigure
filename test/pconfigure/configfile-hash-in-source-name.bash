#include "harness_start.bash"

# The same as a '#' in a BINARIES name, but in a SOURCES name: the
# source and the object compiled from it both end up on rule lines,
# and make reads a '#' on a rule line as the start of a comment.  A
# file called this is unusual, but it is a legal file name, so the
# file is really there and it's the name alone that is refused.
#
# Nothing ever built with one of these in a name, so pconfigure
# refuses the line, naming it, before it writes anything: the
# alternative was a Makefile make couldn't read, and an error about a
# line of generated text that points nowhere near the Configfile line
# responsible.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 'int main(void) { return 0; }' > 'src/ma#in.c'
cat >Configfile <<'EOF'
LANGUAGES   += c
BINARIES    += main
SOURCES     += ma#in.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a name with a '#' in it was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:3" out
grep -qF "has a '#' in it" out
test ! -e Makefile
