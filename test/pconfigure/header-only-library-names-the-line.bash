#include "harness_start.bash"

# The "h" language installs headers by running BASH's targets() on
# them, and like perl it decided what it would take by file name
# alone.  A LIBRARIES whose only source is a header was therefore
# claimed, and then aborted in targets() with "Unimplemented context
# type" and no Configfile line.  A library with nothing to compile in
# it is a mistake in the Configfile, so it gets the same "no language"
# refusal a library of BASH scripts does, which names the line.
#
# The library is deliberately not on the first line, so a message that
# names the wrong one can't pass.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += h

LIBRARIES   += libfoo.so
SOURCES     += foo.h
EOF

cat >src/foo.h <<'EOF'
int foo(void);
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Unable to find language for ./Configfile:3 'LIBRARIES += libfoo.so'" pconfigure.out
if grep -q "Unimplemented context type" pconfigure.out
then
    exit 1
fi
