#include "harness_start.bash"

# The other half of a parenthesis in a CONFIG_DEPS.  make counts the
# '(' in 'notes(1.txt' as opening a nested call inside the
# "$(wildcard ...)" the name is written into, so the call's own ')'
# closes that instead and make stops reading the Makefile with
# "unterminated call to function 'wildcard'" -- on every make, without
# a word about the Configfile line that named the file.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes(1.txt'
cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes(1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

# Unchanged, it reconfigures nothing.
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo 2 >> 'notes(1.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
