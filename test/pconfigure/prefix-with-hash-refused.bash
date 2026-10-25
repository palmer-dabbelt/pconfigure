#include "harness_start.bash"

# A '#' in PREFIX is pasted into the Makefile as text, where it starts
# a comment: 'PREFIX = /opt/a#b' used to be accepted and wrote a
# Makefile that make stops reading with "missing separator".
#
# The line is refused where it was written, naming the character, the
# way a space in a PREFIX is: no Makefile is written for make to choke
# on later, far from the line that caused it.
mkdir -p src
cat >src/main.c <<'EOF2'
#include <stdio.h>
int main(void) { puts(__PCONFIGURE__PREFIX); return 0; }
EOF2

cat >Configfile <<'EOF2'
PREFIX     = /opt/a#b

LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    echo "a PREFIX with a '#' in it was accepted" >&2
    exit 1
fi
cat out

grep -q "Configfile:1" out
grep -qF "error: PREFIX has a '#' in it" out
test ! -e Makefile
