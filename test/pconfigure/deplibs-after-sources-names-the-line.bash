#include "harness_start.bash"

# A DEPLIBS written after a SOURCES lands on the source rather than on
# the target, and is refused.  A LINKOPTS in the same place gets a
# warning that says to move it above the SOURCES (strict.c++), and the
# DEPLIBS -- which the manual calls the same thing as a LINKOPTS --
# should get the same advice, along with the line it is about, rather
# than a sentence about a "SOURCE context".
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
LANGUAGES += c

BINARIES  += app
SOURCES   += main.c
DEPLIBS   += m
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
test ! -e Makefile

grep -q "Configfile:5" out
grep -q "move it above the SOURCES" out
