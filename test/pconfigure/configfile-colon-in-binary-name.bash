#include "harness_start.bash"

# A ':' in a target name is the separator between a target and what
# it depends on as far as make is concerned, so a BINARIES name with
# one in it writes rules make reads as a different, broken shape --
# "target pattern contains no '%'" is what used to come back, about a
# line of the generated Makefile.
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
BINARIES    += hello:world
SOURCES     += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    echo "a name with a ':' in it was accepted" >&2
    exit 1
fi
cat out
grep -q "Configfile:2" out
grep -qF "has a ':' in it" out
test ! -e Makefile
