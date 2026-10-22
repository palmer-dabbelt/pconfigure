#include "harness_start.bash"

# An '=' in a target name turns the rule line it sits on into a
# variable assignment as far as make is concerned, and the recipe
# below it into a recipe with no rule: "recipe commences before first
# target".  Configfile lines are split at the first spaces, so the '='
# is plainly part of the value as pconfigure reads it.
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
BINARIES    += hello=world
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a name with a '=' in it was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "has a '=' in it" out
test ! -e Makefile
