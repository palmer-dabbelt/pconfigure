#include "harness_start.bash"

# A ';' in a PHONY's name: a BINARIES with one is refused at configure
# time naming the line, while a PHONY configures cleanly and leaves
# behind a Makefile that make won't read at all ("missing separator"),
# so every make in the tree -- "make clean" included -- stops on a
# line of generated text rather than on the Configfile line that
# caused it.

mkdir -p test/x
mkdir -p 'test/x;y'

cat >Configfile <<'EOF'
LANGUAGES += bash

PHONY     += x;y
TESTSRC   += t.bash
EOF

cat >'test/x;y/t.bash' <<'EOF'
exit 0
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    make $MAKE_ARGS clean || true
    exit 1
fi
cat configure.out

grep -q "Configfile:3" configure.out
grep -q "PHONY has a ';' in it" configure.out

exit 0
