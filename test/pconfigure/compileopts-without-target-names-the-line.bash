#include "harness_start.bash"

# A COMPILEOPTS with no language and no target above it has nothing
# to land on, which the manual says is a fatal error.  The refusal is
# about where the line sits, so the line is the one thing it can't
# leave out, and "*OPTS target" is not a word anybody writing a
# Configfile has met, so it has to say where the line goes instead.
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

COMPILEOPTS += -Wall
LANGUAGES   += c
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
test ! -e Makefile

grep -q "Configfile:3" out
grep -q "write it below the LANGUAGES" out
