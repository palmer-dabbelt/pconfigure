#include "harness_start.bash"

# A CONFIG_DEPS names a file the Configfile's answer depends on, and
# under AUTORECONFIGURE an edit to it reconfigures.  It reaches the
# Makefile inside a "$(wildcard ...)", where a '$' is an expansion:
# "cost$1.txt" was looked for as "cost.txt", which isn't there, so the
# wildcard came to nothing and the file was silently not watched at
# all.  A '#' in the same place is an ordinary character to make and
# already worked; it is watched here too, so that escaping the one
# does not break the other by turning the '#' into a "\#" the glob
# would then have to match.

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += cost$1.txt
CONFIG_DEPS     += notes#1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

mkdir -p src
echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'cost$1.txt'
echo 1 > 'notes#1.txt'

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

sleep 1
echo 2 > 'cost$1.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log

sleep 1
echo 2 > 'notes#1.txt'
make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
grep -q PCONFIGURE third.log
