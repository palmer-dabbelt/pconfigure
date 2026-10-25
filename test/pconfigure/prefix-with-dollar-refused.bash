#include "harness_start.bash"

# A '$' in PREFIX is pasted into the Makefile unescaped, so make
# expands it: 'PREFIX = /opt/$x' used to build a program that says it
# lives in '/opt/' and install it into '/opt//bin', with nothing said
# about it.  A '$' in a SOURCES or a target name is refused for exactly
# this reason.
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
PREFIX     = /opt/$x

LANGUAGES += c

BINARIES  += main
SOURCES   += main.c
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > out 2>&1
then
    cat out
    echo "a PREFIX with a '\$' in it was accepted" >&2
    exit 1
fi
cat out

grep -q "Configfile:1" out
grep -qF "error: PREFIX has a '\$' in it" out
test ! -e Makefile
