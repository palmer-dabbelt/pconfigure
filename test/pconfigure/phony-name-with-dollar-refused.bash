#include "harness_start.bash"

# A BINARIES with a '$' in it is refused at configure time, naming the
# line, because make reads the name as an expansion.  A PHONY is a name
# that goes onto the left of a rule and onto a .PHONY line in exactly
# the same way, but it isn't on the list of commands that get asked --
# so "PHONY += $(shell touch PWNED)x" configures without a word, and
# make runs the shell command every time it reads the Makefile:
# "make -n", which promises to run nothing, included.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash

PHONY     += $(shell touch PWNED)x
EOF

if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
then
    cat configure.out
    make $MAKE_ARGS -n || true
    ls
    exit 1
fi
cat configure.out

grep -q "Configfile:3" configure.out
grep -q "PHONY has a '\\$' in it" configure.out
test ! -e PWNED

exit 0
