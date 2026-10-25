#include "harness_start.bash"

# AUTODEPS takes "true" or "false".  Anything else is refused, which is
# right, but the refusal is the bare "yes is not boolean": no file, no
# line, and nothing about which two words would have worked.  ABRT_IS_FAIL
# and AUTORECONFIGURE, which ask the same kind of yes-or-no question,
# both name the line and the two answers; AUTODEPS should say as much.
#
# The AUTODEPS is the third line and sits under a BINARIES, where it is
# usually written, so a message that names the target's line or the
# first line can't pass by accident.  The wording is the one the other
# two booleans use, so all three read the same way.
mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfile <<'END'
LANGUAGES += c
BINARIES  += main
AUTODEPS   = yes
SOURCES   += main.c
END

if $PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
then
    cat out
    exit 1
fi
cat out
test ! -e Makefile
grep -q "Configfile:3" out
grep -q "'yes' is not 'true' or 'false'" out
