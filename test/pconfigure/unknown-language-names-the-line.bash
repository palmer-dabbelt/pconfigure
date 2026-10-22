#include "harness_start.bash"

# A language name that isn't one -- "cc", the compiler's name rather
# than the language's -- stops the run, and the refusal has to point
# back at the line that asked for it: LANGUAGES lines are spread over
# every Configfile and CONFIG in a tree, and the name alone doesn't say
# which of them to fix.
#
# The house rule for a fatal error is that it names the Configfile
# line it is about and says what to write instead.  The offending
# line is deliberately not the first one, so a message that names the
# wrong line can't pass by accident.

mkdir -p src

cat >src/main.c <<'EOF'
int main(void) { return 0; }
EOF

cat >Configfile <<'EOF'
STRICT = v0.13

LANGUAGES += cc
BINARIES  += app
SOURCES   += main.c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
test ! -e Makefile

grep -q "Configfile:3" out
grep -q "Unable to find language: 'cc'" out
grep -q "'LANGUAGES += c'" out
