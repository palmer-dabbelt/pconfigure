#include "harness_start.bash"

# A ';' is one character make has no spelling for: on a rule line it
# ends the prerequisites and starts a recipe whether or not a backslash
# is in front of it.  A header called 'a;b.h' can't be written as a
# prerequisite at all, so it is refused, pointing at the SOURCES line
# for the source that reads it, rather than written as a rule that
# runs half its name as a command.

mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES   += c

BINARIES    += app
SOURCES     += main.c
EOF2

cat >'src/a;b.h' <<'EOF2'
#define VALUE 7
EOF2

cat >src/main.c <<'EOF2'
#include "a;b.h"
int main(void) { return VALUE; }
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    exit 1
fi
cat out
grep -q "Configfile:4" out
grep -q "'src/main.c' reads the header 'src/a;b.h', which the Makefile cannot name" out
