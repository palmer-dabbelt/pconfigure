#include "harness_start.bash"

# A single quote in a target name reaches the recipes that copy and
# link it unescaped, where it opens a shell string that never closes.
# Unlike the characters build_system::unsafe_metacharacter() refuses
# it can't be used to run anything, but it did stop the build with a
# shell syntax error about a recipe nobody wrote.
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
BINARIES    += hello'world
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a name with a ''' in it was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "has a ''' in it" out
test ! -e Makefile
