#include "harness_start.bash"

# A CONFIG_DEPS reaches the Makefile inside a "$(wildcard ...)", and
# make reads a '#' inside a function call as part of the argument
# rather than as the start of a comment.  So a file with one in its
# name is still watched: editing it reconfigures under AUTORECONFIGURE.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes#1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes#1.txt'

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

# Unchanged, it reconfigures nothing: a '#' that cut the line short
# would leave a dangling "$(wildcard" or a name that never matches,
# and either could show up as a configure on every build instead.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo 2 > 'notes#1.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
