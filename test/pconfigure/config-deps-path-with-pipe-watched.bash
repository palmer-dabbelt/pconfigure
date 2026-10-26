#include "harness_start.bash"

# Like config-deps-path-with-colon-watched, for a '|'.  The expanded
# name lands on the reconfigure rule's prerequisite list, where make
# reads a '|' as the start of the order-only prerequisites: the rule
# asks for a 'notes' nothing makes and every build stops.

mkdir -p src

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
CONFIG_DEPS     += notes|1.txt
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOC

echo 'int main(void) { return 0; }' > src/main.c
echo 1 > 'notes|1.txt'

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS > first.log 2>&1 || { cat first.log; exit 1; }
cat first.log

# Unchanged, a second make settles.
make $MAKE_ARGS > settled.log 2>&1 || { cat settled.log; exit 1; }
cat settled.log
if grep -q PCONFIGURE settled.log
then
    exit 1
fi

# And an edit to the file is what the line was written for.
sleep 1
echo 2 > 'notes|1.txt'
make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q PCONFIGURE second.log
