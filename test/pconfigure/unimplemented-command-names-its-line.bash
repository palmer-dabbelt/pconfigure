#include "harness_start.bash"

# A command pconfigure parses but has no implementation of is refused,
# and that refusal is a fatal error like any other: it has to say
# which line of which Configfile asked for it.  It used to print
# "Command X not implemented" and nothing else, which in a tree of
# several Configfiles leaves whoever reads it grepping for the
# command.
#
# HDRDIR is the command used here because it is the one that reaches
# that refusal today.  Should it grow an implementation the configure
# succeeds and this test has nothing to say, which is fine: what it
# pins is the shape of the refusal, not that there is one.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES  += c

HDRDIR      = include

BINARIES   += app
SOURCES    += app.c
EOF

cat >src/app.c <<'EOF'
int main(void) { return 0; }
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
then
    exit 0
fi
cat configure.out

grep -q "Configfile:3" configure.out
grep -q "HDRDIR" configure.out

exit 0
