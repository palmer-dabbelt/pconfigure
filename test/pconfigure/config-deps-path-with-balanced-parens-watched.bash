#include "harness_start.bash"

# A CONFIG_DEPS is watched through a "$(wildcard ...)", and make counts
# parentheses to find where that call ends.  A balanced pair in the
# name is counted open and shut again before the call's own ')' is
# reached, so 'notes(1).txt' has always been watched; this pins that it
# still is, now that a lone parenthesis is spelled differently.  Left
# alone, nothing reconfigures; edited, the next make reconfigures.

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes(1).txt'

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes(1).txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log
if grep -q PCONFIGURE first.log
then
    exit 1
fi

sleep 1
echo 2 >> 'notes(1).txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
